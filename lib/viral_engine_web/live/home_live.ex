defmodule ViralEngineWeb.HomeLive do
  use ViralEngineWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-background min-h-screen flex items-center justify-center p-4" role="main">
      <div class="max-w-4xl mx-auto text-center">
        <div class="mb-12">
          <h1 class="text-5xl font-bold text-foreground mb-6">
            Vel Tutor
          </h1>
          <p class="text-xl text-muted-foreground max-w-2xl mx-auto">
            AI-powered learning platform designed for collaborative growth and academic excellence
          </p>
        </div>

        <!-- Primary CTA -->
        <div class="mb-16">
          <a href="/diagnostic" class="inline-flex items-center space-x-2 bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-8 py-4 rounded-md shadow-sm hover:shadow-md transition-all text-lg">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
            </svg>
            <span>Get Started</span>
          </a>
        </div>

        <!-- Feature Cards -->
        <div class="grid md:grid-cols-3 gap-6 mb-16">
          <div class="bg-card text-card-foreground rounded-lg border p-6">
            <div class="w-12 h-12 rounded-lg bg-primary flex items-center justify-center mb-4 mx-auto">
              <svg class="w-6 h-6 text-primary-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
              </svg>
            </div>
            <h3 class="text-lg font-semibold mb-2">Practice Sessions</h3>
            <p class="text-muted-foreground">Interactive learning with adaptive content tailored to your needs</p>
          </div>

          <div class="bg-card text-card-foreground rounded-lg border p-6">
            <div class="w-12 h-12 rounded-lg bg-primary flex items-center justify-center mb-4 mx-auto">
              <svg class="w-6 h-6 text-primary-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
              </svg>
            </div>
            <h3 class="text-lg font-semibold mb-2">Progress Tracking</h3>
            <p class="text-muted-foreground">Monitor your improvement with detailed analytics and insights</p>
          </div>

          <div class="bg-card text-card-foreground rounded-lg border p-6">
            <div class="w-12 h-12 rounded-lg bg-primary flex items-center justify-center mb-4 mx-auto">
              <svg class="w-6 h-6 text-primary-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
            </div>
            <h3 class="text-lg font-semibold mb-2">Collaborative Learning</h3>
            <p class="text-muted-foreground">Study together with friends through challenges and group sessions</p>
          </div>
        </div>

        <!-- Quick Access -->
        <div class="bg-card text-card-foreground rounded-lg border p-8 mb-8">
          <h2 class="text-2xl font-semibold mb-6">Explore Features</h2>
          <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
            <a href="/practice" class="flex items-center space-x-3 p-4 border border-input rounded-md hover:bg-muted transition-colors" aria-label="Start practice sessions">
              <svg class="w-5 h-5 text-primary flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <div class="text-left">
                <div class="font-medium text-foreground">Practice</div>
                <div class="text-sm text-muted-foreground">Start learning</div>
              </div>
            </a>

            <a href="/leaderboard" class="flex items-center space-x-3 p-4 border border-input rounded-md hover:bg-muted transition-colors" aria-label="View leaderboard">
              <svg class="w-5 h-5 text-primary flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
              </svg>
              <div class="text-left">
                <div class="font-medium text-foreground">Leaderboard</div>
                <div class="text-sm text-muted-foreground">See rankings</div>
              </div>
            </a>

            <a href="/badges" class="flex items-center space-x-3 p-4 border border-input rounded-md hover:bg-muted transition-colors" aria-label="View badges and achievements">
              <svg class="w-5 h-5 text-primary flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" />
              </svg>
              <div class="text-left">
                <div class="font-medium text-foreground">Badges</div>
                <div class="text-sm text-muted-foreground">Achievements</div>
              </div>
            </a>

            <a href="/flashcards" class="flex items-center space-x-3 p-4 border border-input rounded-md hover:bg-muted transition-colors" aria-label="Study with flashcards">
              <svg class="w-5 h-5 text-primary flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 7V3a2 2 0 012-2z" />
              </svg>
              <div class="text-left">
                <div class="font-medium text-foreground">Flashcards</div>
                <div class="text-sm text-muted-foreground">Quick review</div>
              </div>
            </a>

            <a href="/diagnostic" class="flex items-center space-x-3 p-4 border border-input rounded-md hover:bg-muted transition-colors" aria-label="Take diagnostic assessment">
              <svg class="w-5 h-5 text-primary flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
              </svg>
              <div class="text-left">
                <div class="font-medium text-foreground">Diagnostic</div>
                <div class="text-sm text-muted-foreground">Assess level</div>
              </div>
            </a>

            <a href="/dashboard" class="flex items-center space-x-3 p-4 border border-input rounded-md hover:bg-muted transition-colors" aria-label="View dashboard">
              <svg class="w-5 h-5 text-primary flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2H5a2 2 0 00-2-2z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5a2 2 0 012-2h4a2 2 0 012 2v2H8V5z" />
              </svg>
              <div class="text-left">
                <div class="font-medium text-foreground">Dashboard</div>
                <div class="text-sm text-muted-foreground">Overview</div>
              </div>
            </a>
          </div>
        </div>

        <p class="text-sm text-muted-foreground">
          Most features require authentication to access personalized content.
        </p>
      </div>
    </div>
    """
  end
end
