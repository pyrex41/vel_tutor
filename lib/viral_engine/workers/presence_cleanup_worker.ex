defmodule ViralEngine.Workers.PresenceCleanupWorker do
  use Oban.Worker, queue: :default

  alias ViralEngine.PresenceTracking

  @impl Oban.Worker
  def perform(_job) do
    {deleted_count, _} = PresenceTracking.cleanup_stale_sessions()

    if deleted_count > 0 do
      require Logger
      Logger.info("Cleaned up #{deleted_count} stale presence sessions")
    end

    :ok
  end
end
