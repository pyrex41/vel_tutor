defmodule ViralEngineWeb.ComplianceMiddleware do
  @moduledoc """
  Phoenix plug for enforcing COPPA/FERPA compliance on sensitive endpoints.

  This middleware:
  1. Identifies requests that require compliance checks
  2. Extracts user context from conn (headers, session, IP)
  3. Calls TrustSafety agent to verify compliance
  4. Blocks non-compliant requests with appropriate error responses
  5. Logs compliance checks for audit purposes

  ## Usage

  Add to router pipeline for sensitive routes:

      pipeline :protected do
        plug :accepts, ["json"]
        plug :fetch_session
        plug ViralEngineWeb.ComplianceMiddleware
      end

      scope "/api/sensitive", ViralEngineWeb do
        pipe_through :protected
        # Routes requiring compliance checks
      end
  """

  import Plug.Conn
  import Phoenix.Controller
  require Logger

  alias ViralEngine.Agents.TrustSafety

  @behaviour Plug

  # Paths that require COPPA/FERPA compliance checks
  @sensitive_paths [
    ~r{^/api/users/\d+/profile$},
    ~r{^/api/users/\d+/share},
    ~r{^/api/sessions/\d+/transcript},
    ~r{^/api/social/},
    ~r{^/api/export/},
    ~r{^/api/public-profile/}
  ]

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    if requires_compliance_check?(conn) do
      perform_compliance_check(conn)
    else
      conn
    end
  end

  defp requires_compliance_check?(conn) do
    path = conn.request_path

    Enum.any?(@sensitive_paths, fn pattern ->
      Regex.match?(pattern, path)
    end)
  end

  defp perform_compliance_check(conn) do
    context = extract_context(conn)

    # Require user_id for compliance checks
    if is_nil(context[:user_id]) do
      Logger.warning("Compliance check failed: no user_id found in request to #{conn.request_path}")
      block_request(conn, :authentication_required)
    else
      check_with_trust_safety(conn, context)
    end
  end

  defp check_with_trust_safety(conn, context) do
    case TrustSafety.check_action(context) do
      {:ok, :allowed} ->
        Logger.debug("Compliance check passed for #{conn.request_path}")
        conn

      {:error, :parental_consent_required} ->
        Logger.warning(
          "Compliance check failed: parental consent required for user #{context[:user_id]}"
        )

        block_request(conn, :parental_consent_required)

      {:error, :consent_withdrawn} ->
        Logger.warning("Compliance check failed: consent withdrawn for user #{context[:user_id]}")
        block_request(conn, :consent_withdrawn)

      {:error, :user_blocked} ->
        Logger.warning("Compliance check failed: user blocked #{context[:user_id]}")
        block_request(conn, :user_blocked)

      {:error, :device_blocked} ->
        Logger.warning(
          "Compliance check failed: device blocked #{context[:device_id] || "unknown"}"
        )

        block_request(conn, :device_blocked)

      {:error, :fraud_detected} ->
        Logger.error("Compliance check failed: fraud detected for user #{context[:user_id]}")
        block_request(conn, :fraud_detected)

      {:error, :rate_limited} ->
        Logger.warning("Compliance check failed: rate limited for user #{context[:user_id]}")
        block_request(conn, :rate_limited)

      {:error, reason} ->
        Logger.error(
          "Compliance check failed with unknown reason: #{inspect(reason)} for user #{context[:user_id]}"
        )

        block_request(conn, :compliance_check_failed)
    end
  end

  defp extract_context(conn) do
    # Extract user ID from session or JWT token
    user_id = get_user_id(conn)

    # Extract device ID from headers
    device_id = get_req_header(conn, "x-device-id") |> List.first()

    # Get IP address
    ip_address = get_ip_address(conn)

    # Determine action type from request method and path
    action_type = determine_action_type(conn)

    # Get user agent
    user_agent = get_req_header(conn, "user-agent") |> List.first()

    %{
      user_id: user_id,
      device_id: device_id,
      ip_address: ip_address,
      action_type: action_type,
      user_agent: user_agent,
      request_path: conn.request_path,
      request_method: conn.method
    }
  end

  defp get_user_id(conn) do
    # Try to get user ID from conn.assigns (set by authentication plug)
    case Map.get(conn.assigns, :current_user) do
      nil ->
        # Try to get from session
        get_session(conn, :user_id)

      user ->
        user.id
    end
  end

  defp get_ip_address(conn) do
    # Check for forwarded IP first (for proxies/load balancers)
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        # Take first IP if multiple
        forwarded |> String.split(",") |> hd() |> String.trim()

      [] ->
        # Fall back to remote_ip
        case conn.remote_ip do
          {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
          ip -> to_string(ip)
        end
    end
  end

  defp determine_action_type(conn) do
    cond do
      String.contains?(conn.request_path, "/share") ->
        "share_personal_info"

      String.contains?(conn.request_path, "/public-profile") ->
        "public_profile"

      String.contains?(conn.request_path, "/social") ->
        "social_features"

      String.contains?(conn.request_path, "/export") ->
        "data_export"

      String.contains?(conn.request_path, "/profile") && conn.method == "PUT" ->
        "update_profile"

      true ->
        "sensitive_access"
    end
  end

  defp block_request(conn, reason) do
    {status, error_code, message} = get_error_details(reason)

    conn
    |> put_status(status)
    |> put_resp_content_type("application/json")
    |> json(%{
      error: error_code,
      message: message,
      compliance_required: true,
      support_contact: "support@veltutor.com"
    })
    |> halt()
  end

  defp get_error_details(:parental_consent_required) do
    {403, "parental_consent_required",
     "This action requires parental consent. Please have a parent or guardian complete the consent process."}
  end

  defp get_error_details(:consent_withdrawn) do
    {403, "consent_withdrawn",
     "Parental consent has been withdrawn. Please contact support for more information."}
  end

  defp get_error_details(:user_blocked) do
    {403, "user_blocked",
     "Your account has been blocked due to trust and safety concerns. Please contact support."}
  end

  defp get_error_details(:device_blocked) do
    {403, "device_blocked",
     "This device has been blocked due to suspicious activity. Please contact support."}
  end

  defp get_error_details(:fraud_detected) do
    {403, "fraud_detected",
     "This request has been blocked due to fraud detection. Please contact support if you believe this is an error."}
  end

  defp get_error_details(:rate_limited) do
    {429, "rate_limited",
     "Too many requests. Please slow down and try again later."}
  end

  defp get_error_details(:authentication_required) do
    {401, "authentication_required",
     "You must be logged in to access this resource."}
  end

  defp get_error_details(_reason) do
    {403, "compliance_check_failed",
     "This action cannot be completed at this time. Please contact support if the issue persists."}
  end
end
