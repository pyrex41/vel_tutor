defmodule ViralEngineWeb.HomeLive do
  use ViralEngineWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white">
      <!-- Hero Section -->
      <div class="relative overflow-hidden">
        <div class="absolute inset-0 bg-gradient-to-br from-blue-50 via-white to-indigo-50"></div>
        <div class="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-24">
          <div class="text-center">
            <h1 class="text-5xl sm:text-6xl font-bold text-gray-900 mb-6 tracking-tight">
              Vel Tutor
            </h1>
            <p class="text-xl sm:text-2xl text-gray-600 mb-12 max-w-3xl mx-auto">
              AI-Powered Learning Platform with Viral Growth Loops
            </p>

            <!-- CTA Buttons -->
            <div class="flex flex-col sm:flex-row gap-4 justify-center mb-16">
              <a href="/practice" class="inline-flex items-center justify-center px-8 py-3 border border-transparent text-base font-medium rounded-lg text-white bg-blue-600 hover:bg-blue-700 transition-colors">
                Start Learning
                <svg class="ml-2 w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7l5 5m0 0l-5 5m5-5H6"/>
                </svg>
              </a>
              <a href="/diagnostic" class="inline-flex items-center justify-center px-8 py-3 border border-gray-300 text-base font-medium rounded-lg text-gray-700 bg-white hover:bg-gray-50 transition-colors">
                Take Diagnostic
              </a>
            </div>

            <!-- Feature Cards -->
            <div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-6">
              <!-- Practice Card -->
              <div class="bg-white border border-zinc-200 rounded-lg p-6 hover:shadow-lg transition-shadow">
                <div class="inline-flex items-center justify-center w-12 h-12 rounded-lg bg-blue-100 text-blue-600 mb-4">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
                  </svg>
                </div>
                <h3 class="text-lg font-semibold text-gray-900 mb-2">Practice Sessions</h3>
                <p class="text-gray-600 text-sm mb-4">Interactive learning with adaptive AI-powered content</p>
                <a href="/practice" class="text-blue-600 text-sm font-medium hover:text-blue-700">
                  Get started →
                </a>
              </div>

              <!-- Leaderboard Card -->
              <div class="bg-white border border-zinc-200 rounded-lg p-6 hover:shadow-lg transition-shadow">
                <div class="inline-flex items-center justify-center w-12 h-12 rounded-lg bg-yellow-100 text-yellow-600 mb-4">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z"/>
                  </svg>
                </div>
                <h3 class="text-lg font-semibold text-gray-900 mb-2">Leaderboards</h3>
                <p class="text-gray-600 text-sm mb-4">Compete with friends and track your progress</p>
                <a href="/leaderboard" class="text-blue-600 text-sm font-medium hover:text-blue-700">
                  View rankings →
                </a>
              </div>

              <!-- Challenges Card -->
              <div class="bg-white border border-zinc-200 rounded-lg p-6 hover:shadow-lg transition-shadow">
                <div class="inline-flex items-center justify-center w-12 h-12 rounded-lg bg-purple-100 text-purple-600 mb-4">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                  </svg>
                </div>
                <h3 class="text-lg font-semibold text-gray-900 mb-2">Challenges</h3>
                <p class="text-gray-600 text-sm mb-4">Challenge friends to friendly competitions</p>
                <a href="/challenges" class="text-blue-600 text-sm font-medium hover:text-blue-700">
                  Start challenge →
                </a>
              </div>

              <!-- Badges Card -->
              <div class="bg-white border border-zinc-200 rounded-lg p-6 hover:shadow-lg transition-shadow">
                <div class="inline-flex items-center justify-center w-12 h-12 rounded-lg bg-green-100 text-green-600 mb-4">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z"/>
                  </svg>
                </div>
                <h3 class="text-lg font-semibold text-gray-900 mb-2">Achievements</h3>
                <p class="text-gray-600 text-sm mb-4">Unlock badges and showcase your skills</p>
                <a href="/badges" class="text-blue-600 text-sm font-medium hover:text-blue-700">
                  View badges →
                </a>
              </div>

              <!-- Flashcards Card -->
              <div class="bg-white border border-zinc-200 rounded-lg p-6 hover:shadow-lg transition-shadow">
                <div class="inline-flex items-center justify-center w-12 h-12 rounded-lg bg-red-100 text-red-600 mb-4">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
                  </svg>
                </div>
                <h3 class="text-lg font-semibold text-gray-900 mb-2">Flashcards</h3>
                <p class="text-gray-600 text-sm mb-4">Study with AI-generated flashcard decks</p>
                <a href="/flashcards" class="text-blue-600 text-sm font-medium hover:text-blue-700">
                  Study now →
                </a>
              </div>

              <!-- Dashboard Card -->
              <div class="bg-white border border-zinc-200 rounded-lg p-6 hover:shadow-lg transition-shadow">
                <div class="inline-flex items-center justify-center w-12 h-12 rounded-lg bg-indigo-100 text-indigo-600 mb-4">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
                  </svg>
                </div>
                <h3 class="text-lg font-semibold text-gray-900 mb-2">Dashboard</h3>
                <p class="text-gray-600 text-sm mb-4">Monitor activity and performance metrics</p>
                <a href="/dashboard/presence" class="text-blue-600 text-sm font-medium hover:text-blue-700">
                  View dashboard →
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Stats Section -->
      <div class="bg-gray-50 py-16">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="grid sm:grid-cols-3 gap-8">
            <div class="text-center">
              <div class="text-4xl font-bold text-blue-600 mb-2">10k+</div>
              <div class="text-gray-600">Practice Sessions</div>
            </div>
            <div class="text-center">
              <div class="text-4xl font-bold text-blue-600 mb-2">500+</div>
              <div class="text-gray-600">Active Learners</div>
            </div>
            <div class="text-center">
              <div class="text-4xl font-bold text-blue-600 mb-2">95%</div>
              <div class="text-gray-600">Success Rate</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Footer Note -->
      <div class="bg-blue-50 border-t border-blue-100 py-6">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <p class="text-center text-sm text-blue-600">
            <svg class="inline w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/>
            </svg>
            Most features require authentication which isn't set up yet
          </p>
        </div>
      </div>
    </div>
    """
  end
end
