defmodule ViralEngineWeb.HomeLive do
  use ViralEngineWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div class="max-w-4xl mx-auto text-center">
        <h1 class="text-6xl font-bold text-gray-900 mb-6">
          Vel Tutor
        </h1>

        <p class="text-2xl text-gray-700 mb-12">
          AI-Powered Learning Platform with Viral Growth Loops
        </p>

        <div class="grid md:grid-cols-3 gap-6 mb-12">
          <div class="bg-white rounded-lg shadow-lg p-6">
            <div class="text-4xl mb-4">📚</div>
            <h3 class="text-xl font-semibold mb-2">Practice Sessions</h3>
            <p class="text-gray-600">Interactive learning with adaptive content</p>
          </div>

          <div class="bg-white rounded-lg shadow-lg p-6">
            <div class="text-4xl mb-4">🏆</div>
            <h3 class="text-xl font-semibold mb-2">Leaderboards</h3>
            <p class="text-gray-600">Compete with friends and track progress</p>
          </div>

          <div class="bg-white rounded-lg shadow-lg p-6">
            <div class="text-4xl mb-4">🎯</div>
            <h3 class="text-xl font-semibold mb-2">Challenges</h3>
            <p class="text-gray-600">Challenge buddies to friendly competitions</p>
          </div>
        </div>

        <div class="bg-white rounded-lg shadow-xl p-8 mb-8">
          <h2 class="text-3xl font-bold mb-4">Available Pages</h2>
          <div class="grid md:grid-cols-2 gap-4 text-left">
            <a href="/practice" class="block p-4 border border-gray-200 rounded hover:bg-blue-50 transition">
              <strong>Practice Sessions</strong> - Start learning
            </a>
            <a href="/leaderboard" class="block p-4 border border-gray-200 rounded hover:bg-blue-50 transition">
              <strong>Leaderboard</strong> - See top performers
            </a>
            <a href="/badges" class="block p-4 border border-gray-200 rounded hover:bg-blue-50 transition">
              <strong>Badges</strong> - View achievements
            </a>
            <a href="/flashcards" class="block p-4 border border-gray-200 rounded hover:bg-blue-50 transition">
              <strong>Flashcards</strong> - Study with cards
            </a>
            <a href="/diagnostic" class="block p-4 border border-gray-200 rounded hover:bg-blue-50 transition">
              <strong>Diagnostic</strong> - Assess your level
            </a>
            <a href="/dashboard/presence" class="block p-4 border border-gray-200 rounded hover:bg-blue-50 transition">
              <strong>Dashboard</strong> - Monitor activity
            </a>
          </div>
        </div>

        <p class="text-sm text-gray-500">
          Note: Most features require authentication which isn't set up yet.
        </p>
      </div>
    </div>
    """
  end
end
