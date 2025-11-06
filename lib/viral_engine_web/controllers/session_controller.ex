defmodule ViralEngineWeb.SessionController do
  use ViralEngineWeb, :controller

  alias ViralEngine.TranscriptContext

  @doc """
  Gets the transcript for a session.
  """
  def get_transcript(conn, %{"id" => session_id}) do
    case TranscriptContext.get_session_transcript(session_id) do
      {:ok, transcript} ->
        json(conn, %{transcript: transcript})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Transcript not found"})
    end
  end

  @doc """
  Exports session data.
  """
  def export_session_data(conn, %{"id" => session_id}) do
    # Stub implementation - should export session data in appropriate format
    json(conn, %{message: "Session #{session_id} export initiated"})
  end
end