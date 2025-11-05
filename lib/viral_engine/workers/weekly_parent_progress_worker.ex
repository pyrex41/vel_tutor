defmodule ViralEngine.Workers.WeeklyParentProgressWorker do
  @moduledoc """
  Oban worker that generates and emails weekly progress reels to parents.

  Implements the "Proud Parent" viral loop by:
  1. Generating privacy-safe weekly progress cards for active students
  2. Emailing reels to parents with shareable referral links
  3. Tracking conversions when parents share with other parents

  Runs weekly on Sunday evenings to recap the week's learning.
  """

  use Oban.Worker,
    queue: :scheduled,
    max_attempts: 3

  alias ViralEngine.{
    Repo,
    ParentShareContext,
    AttributionContext
  }

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("WeeklyParentProgressWorker: Generating weekly progress reels")

    # Find active students from last 7 days
    students_with_activity = find_active_students()

    Logger.info("Found #{length(students_with_activity)} active students for weekly reels")

    # Generate and send progress reels
    results =
      Enum.map(students_with_activity, fn student_data ->
        case generate_and_send_weekly_reel(student_data) do
          {:ok, share} ->
            Logger.info(
              "Weekly reel sent for student #{student_data.student_id}, parent: #{student_data.parent_email}"
            )

            {:ok, share}

          {:skip, reason} ->
            Logger.debug("Skipped weekly reel for student #{student_data.student_id}: #{reason}")
            {:skip, reason}

          {:error, reason} ->
            Logger.error(
              "Failed to send weekly reel for student #{student_data.student_id}: #{inspect(reason)}"
            )

            {:error, reason}
        end
      end)

    success_count = Enum.count(results, fn {status, _} -> status == :ok end)

    Logger.info(
      "Weekly parent progress reels sent: #{success_count}/#{length(students_with_activity)}"
    )

    :ok
  end

  @doc """
  Finds students with activity in the last 7 days who have parent email on file.
  """
  def find_active_students do
    # In production, query database for:
    # 1. Students with completed sessions in last 7 days
    # 2. Students who have parent email on file
    # 3. Students whose parents haven't opted out of emails

    # Query structure:
    # from(u in User,
    #   join: ps in PracticeSession, on: ps.user_id == u.id,
    #   where: ps.completed == true and
    #          ps.updated_at >= ^DateTime.add(DateTime.utc_now(), -7, :day) and
    #          not is_nil(u.parent_email) and
    #          u.parent_email_opt_in == true,
    #   group_by: [u.id, u.parent_email],
    #   having: count(ps.id) >= 2,  # At least 2 sessions this week
    #   select: %{
    #     student_id: u.id,
    #     parent_email: u.parent_email,
    #     sessions_count: count(ps.id)
    #   }
    # )
    # |> Repo.all()

    # Simulated: Return empty list for now
    []
  end

  @doc """
  Generates weekly progress reel and sends email to parent.
  """
  def generate_and_send_weekly_reel(student_data) do
    %{student_id: student_id, parent_email: parent_email} = student_data

    # Check if already sent this week
    if already_sent_this_week?(student_id) do
      {:skip, :already_sent_this_week}
    else
      # Create parent share with weekly_progress type
      case ParentShareContext.create_share(student_id, "weekly_progress",
             parent_email: parent_email
           ) do
        {:ok, share} ->
          # Create attribution link for parent referrals
          {:ok, attribution_link} = create_referral_attribution_link(share)

          # Send email to parent
          send_weekly_progress_email(share, attribution_link, parent_email)

          {:ok, share}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Creates an attribution link for tracking parent referrals.
  """
  def create_referral_attribution_link(share) do
    target_url = "/signup?source=parent_referral&ref=#{share.share_token}"

    AttributionContext.create_attribution_link(
      share.student_id,
      "parent_share",
      target_url,
      campaign: "weekly_progress_reel",
      metadata: %{
        share_id: share.id,
        share_token: share.share_token,
        share_type: share.share_type
      },
      expires_in_days: 30
    )
  end

  @doc """
  Sends weekly progress email to parent.
  """
  def send_weekly_progress_email(share, attribution_link, parent_email) do
    share_link = ParentShareContext.generate_share_link(share)
    referral_link = build_referral_url(attribution_link.link_token)

    # Get progress data for email preview
    progress = share.progress_data

    # Build email
    email =
      build_progress_email(
        to: parent_email,
        share_link: share_link,
        referral_link: referral_link,
        progress: progress
      )

    # Send via Swoosh
    case ViralEngine.Mailer.deliver(email) do
      {:ok, _metadata} ->
        Logger.info("Weekly progress email sent to #{parent_email}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to send email to #{parent_email}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private helpers

  defp already_sent_this_week?(student_id) do
    # Check if a weekly_progress share was created in last 7 days
    cutoff = DateTime.add(DateTime.utc_now(), -7 * 24 * 3600, :second)

    import Ecto.Query

    from(s in ViralEngine.ParentShare,
      where:
        s.student_id == ^student_id and
          s.share_type == "weekly_progress" and
          s.shared_at >= ^cutoff
    )
    |> Repo.exists?()
  end

  defp build_referral_url(link_token) do
    base_url = ViralEngineWeb.Endpoint.url()
    "#{base_url}/invite/#{link_token}"
  end

  defp build_progress_email(opts) do
    import Swoosh.Email

    to_email = opts[:to]
    share_link = opts[:share_link]
    referral_link = opts[:referral_link]
    progress = opts[:progress]

    new()
    |> to(to_email)
    |> from({"Vel Tutor", "no-reply@veltutor.com"})
    |> subject("📊 Your child's weekly learning progress")
    |> html_body("""
    <html>
      <head>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px 10px 0 0; text-align: center; }
          .content { background: #ffffff; padding: 30px; border: 1px solid #e5e7eb; border-top: none; }
          .stat { background: #f9fafb; padding: 20px; margin: 15px 0; border-radius: 8px; border-left: 4px solid #667eea; }
          .stat h3 { margin: 0 0 8px 0; color: #374151; font-size: 14px; font-weight: 500; }
          .stat p { margin: 0; color: #111827; font-size: 28px; font-weight: 700; }
          .cta { display: inline-block; background: #667eea; color: white; padding: 14px 28px; border-radius: 8px; text-decoration: none; font-weight: 600; margin: 10px 0; }
          .cta:hover { background: #5568d3; }
          .referral { background: #fef3c7; border: 2px solid #fbbf24; padding: 20px; border-radius: 8px; margin-top: 30px; }
          .footer { text-align: center; padding: 20px; color: #6b7280; font-size: 14px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1 style="margin: 0;">📊 Weekly Progress Report</h1>
            <p style="margin: 10px 0 0 0; opacity: 0.9;">See how your child learned this week</p>
          </div>

          <div class="content">
            <h2 style="color: #111827; margin-top: 0;">This Week's Highlights</h2>

            <div class="stat">
              <h3>Sessions Completed</h3>
              <p>#{progress["sessions_completed"] || 0}</p>
            </div>

            <div class="stat">
              <h3>Average Score</h3>
              <p>#{round(progress["average_score"] || 0)}%</p>
            </div>

            <div class="stat">
              <h3>Subjects Studied</h3>
              <p>#{length(progress["subjects_studied"] || [])}</p>
            </div>

            <p style="margin-top: 25px;">
              <strong>#{progress["improvement_message"] || "Great progress this week!"}</strong>
            </p>

            <div style="text-align: center; margin: 30px 0;">
              <a href="#{share_link}" class="cta">View Full Progress Report</a>
            </div>

            <div class="referral">
              <h3 style="margin: 0 0 10px 0; color: #92400e;">🎁 Share & Get a Free Class Pass!</h3>
              <p style="margin: 0 0 15px 0; color: #78350f;">
                Know another parent who'd love to see their child thrive?
                Share this link and you'll both get a <strong>free class pass</strong> when they sign up!
              </p>
              <a href="#{referral_link}" class="cta" style="background: #f59e0b;">Share with Friends</a>
            </div>
          </div>

          <div class="footer">
            <p>You're receiving this because your child is making progress on Vel Tutor.</p>
            <p style="margin-top: 10px;">
              <a href="#" style="color: #6b7280;">Unsubscribe</a> |
              <a href="#" style="color: #6b7280;">Preferences</a>
            </p>
          </div>
        </div>
      </body>
    </html>
    """)
    |> text_body("""
    Weekly Progress Report
    ====================

    This Week's Highlights:

    Sessions Completed: #{progress["sessions_completed"] || 0}
    Average Score: #{round(progress["average_score"] || 0)}%
    Subjects Studied: #{length(progress["subjects_studied"] || [])}

    #{progress["improvement_message"] || "Great progress this week!"}

    View Full Progress Report: #{share_link}

    ---

    Share & Get a Free Class Pass!

    Know another parent who'd love to see their child thrive?
    Share this link and you'll both get a free class pass when they sign up!

    Referral Link: #{referral_link}

    ---

    You're receiving this because your child is making progress on Vel Tutor.
    """)
  end

  @doc """
  Enqueues the worker to run weekly on Sunday evenings at 6 PM.
  """
  def schedule_weekly do
    # Sunday at 6 PM (cron: minute hour day month weekday)
    %{}
    |> __MODULE__.new(schedule: "0 18 * * 0")
    |> Oban.insert()
  end
end
