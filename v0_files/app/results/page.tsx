export default function ResultsPage() {
  return (
    <html lang="en">
      <head>
        <meta charSet="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Session Results - Varsity Tutors</title>
        <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
        <link rel="stylesheet" href="/styles.css" />
      </head>
      <body className="bg-white text-black min-h-screen">
        <div dangerouslySetInnerHTML={{ __html: htmlContent }} />
        <script dangerouslySetInnerHTML={{ __html: jsContent }} />
      </body>
    </html>
  )
}

const htmlContent = `
  <div x-data="resultsApp()" class="min-h-screen bg-white">
    <!-- Header -->
    <header class="border-b border-zinc-200 bg-white/90 backdrop-blur-sm sticky top-0 z-50">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 bg-white border border-blue-500/30 rounded flex items-center justify-center font-bold text-xl text-blue-600">
              VT
            </div>
            <h1 class="text-xl font-bold text-black">Varsity Tutors</h1>
          </div>
          
          <nav class="flex items-center gap-6">
            <a href="/" class="text-zinc-500 hover:text-black transition-colors">Dashboard</a>
            <a href="/results" class="text-blue-600 font-medium transition-colors">Results</a>
            <a href="/challenge" class="text-zinc-500 hover:text-black transition-colors">Challenge</a>
          </nav>

          <div class="flex items-center gap-4">
            <div class="flex items-center gap-2 px-3 py-1.5 bg-zinc-50 border border-zinc-200 rounded-full">
              <span class="text-sm font-medium text-zinc-700">2500 XP</span>
            </div>
            <div class="w-10 h-10 rounded-full bg-zinc-100 border border-zinc-300 flex items-center justify-center font-bold">
              <img src="/student-avatar.png" alt="Profile" class="w-full h-full rounded-full object-cover" />
            </div>
          </div>
        </div>
      </div>
    </header>

    <!-- Results Content -->
    <main class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      
      <!-- Celebration Header -->
      <div class="text-center mb-8">
        <div class="flex justify-center mb-4">
          <svg class="w-16 h-16 text-blue-600 animate-pulse" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z"/>
            <path d="M5 3v4"/>
            <path d="M19 17v4"/>
            <path d="M3 5h4"/>
            <path d="M17 19h4"/>
          </svg>
        </div>
        <h1 class="text-4xl font-bold mb-2 text-black">Great Session!</h1>
        <p class="text-xl text-zinc-600">You earned <span class="text-blue-600 font-bold">+50 XP</span></p>
      </div>

      <!-- Results Card -->
      <div class="bg-white border border-zinc-200 rounded-lg p-8 mb-8">
        
        <!-- Score Display -->
        <div class="text-center mb-8">
          <div class="inline-flex items-center justify-center w-32 h-32 rounded-full bg-blue-600 mb-4">
            <span class="text-5xl font-bold text-white">85%</span>
          </div>
          <h2 class="text-2xl font-bold mb-2 text-black">Algebra Practice</h2>
          <p class="text-zinc-600">17 out of 20 correct</p>
        </div>

        <!-- Stats Grid -->
        <div class="grid grid-cols-3 gap-4 mb-8">
          <div class="bg-zinc-50 border border-zinc-200 rounded-lg p-4 text-center">
            <p class="text-3xl font-bold text-blue-600">12:34</p>
            <p class="text-sm text-zinc-500 mt-1">Time Spent</p>
          </div>
          <div class="bg-zinc-50 border border-zinc-200 rounded-lg p-4 text-center">
            <p class="text-3xl font-bold text-blue-600">13</p>
            <p class="text-sm text-zinc-500 mt-1">Day Streak</p>
          </div>
          <div class="bg-zinc-50 border border-zinc-200 rounded-lg p-4 text-center">
            <p class="text-3xl font-bold text-blue-600">+50</p>
            <p class="text-sm text-zinc-500 mt-1">XP Earned</p>
          </div>
        </div>

        <!-- Achievements -->
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-6 mb-6">
          <h3 class="font-bold mb-3 flex items-center gap-2 text-black">
            <svg class="w-5 h-5 text-blue-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/>
              <path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/>
              <path d="M4 22h16"/>
              <path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/>
              <path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/>
              <path d="M18 2H6v7a6 6 0 0 0 12 0V2Z"/>
            </svg>
            New Achievement Unlocked!
          </h3>
          <p class="text-zinc-700">Algebra Apprentice - Complete 10 algebra sessions</p>
        </div>

        <!-- Share Section -->
        <div class="border-t border-zinc-200 pt-6">
          <h3 class="font-bold mb-4 text-center text-black">Share Your Progress!</h3>
          <div class="flex gap-3 mb-4">
            <button class="flex-1 px-4 py-3 bg-zinc-50 text-zinc-700 rounded-lg hover:bg-zinc-100 transition-colors flex items-center justify-center gap-2 border border-zinc-200">
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/></svg>
              Twitter
            </button>
            <button class="flex-1 px-4 py-3 bg-zinc-50 text-zinc-700 rounded-lg hover:bg-zinc-100 transition-colors flex items-center justify-center gap-2 border border-zinc-200">
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.012-3.584.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z"/></svg>
              Instagram
            </button>
            <button class="flex-1 px-4 py-3 bg-zinc-50 text-zinc-700 rounded-lg hover:bg-zinc-100 transition-colors flex items-center justify-center gap-2 border border-zinc-200">
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z"/></svg>
              WhatsApp
            </button>
          </div>
          <p class="text-center text-sm text-zinc-500">Invite friends and earn 100 XP each!</p>
        </div>
      </div>

      <!-- Viral CTA -->
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-8 text-center">
        <div class="flex items-center justify-center gap-2 mb-3">
          <svg class="w-6 h-6 text-blue-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="12" cy="12" r="10"/>
            <circle cx="12" cy="12" r="6"/>
            <circle cx="12" cy="12" r="2"/>
          </svg>
          <h3 class="text-2xl font-bold text-black">Challenge a Friend!</h3>
        </div>
        <p class="text-zinc-700 mb-6">Think you can beat their score? Send them a challenge and compete for bonus XP!</p>
        <a href="/challenge" class="inline-block px-8 py-3 bg-blue-600 text-white rounded-lg font-semibold hover:bg-blue-700 transition-colors">
          Start Challenge
        </a>
      </div>

      <!-- Continue Button -->
      <div class="mt-8 text-center">
        <a href="/" class="inline-block px-8 py-3 bg-zinc-100 text-zinc-700 rounded-lg hover:bg-zinc-200 transition-colors border border-zinc-200">
          Back to Dashboard
        </a>
      </div>

    </main>
  </div>
`

const jsContent = `
function resultsApp() {
  return {}
}
`
