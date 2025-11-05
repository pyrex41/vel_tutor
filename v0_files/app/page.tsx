"use client"

import { useEffect } from "react"

export default function Page() {
  useEffect(() => {
    // Force Alpine to initialize after component mounts
    if (typeof window !== "undefined" && (window as any).Alpine) {
      ;(window as any).Alpine.start()
    }
  }, [])

  return (
    <html lang="en">
      <head>
        <meta charSet="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Varsity Tutors - Dashboard</title>
        <script src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js" defer></script>
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
  <div x-data="app()" class="min-h-screen bg-white">
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
            <a href="/" class="text-blue-600 font-medium transition-colors">Dashboard</a>
            <a href="/results" class="text-zinc-500 hover:text-black transition-colors">Results</a>
            <a href="/challenge" class="text-zinc-500 hover:text-black transition-colors">Challenge</a>
          </nav>

          <div class="flex items-center gap-4">
            <div class="flex items-center gap-2 px-3 py-1.5 bg-zinc-50 border border-zinc-200 rounded-full">
              <span class="text-sm font-medium text-zinc-700" x-text="user.xp + ' XP'"></span>
            </div>
            <div class="w-10 h-10 rounded-full bg-zinc-100 border border-zinc-300 flex items-center justify-center font-bold">
              <img src="/student-avatar.png" alt="Profile" class="w-full h-full rounded-full object-cover" />
            </div>
          </div>
        </div>
      </div>
    </header>

    <!-- Main Content -->
    <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      
      <!-- Live Presence Banner -->
      <div class="mb-8 bg-zinc-50 border border-zinc-200 rounded-lg p-6">
        <div class="flex items-center justify-between flex-wrap gap-4">
          <div class="flex items-center gap-3">
            <div class="relative">
              <div class="w-3 h-3 bg-blue-500 rounded-full animate-pulse"></div>
              <div class="absolute inset-0 w-3 h-3 bg-blue-500 rounded-full animate-ping"></div>
            </div>
            <div>
              <p class="text-lg font-semibold text-black">
                <span x-text="liveStats.activeStudents"></span> students learning right now
              </p>
              <p class="text-sm text-zinc-500">Join the momentum</p>
            </div>
          </div>
          <div class="flex items-center gap-6">
            <div class="text-center">
              <p class="text-2xl font-bold text-black" x-text="liveStats.sessionsToday"></p>
              <p class="text-xs text-zinc-500">Sessions Today</p>
            </div>
            <div class="text-center">
              <p class="text-2xl font-bold text-blue-600">Calculus</p>
              <p class="text-xs text-zinc-500">Trending Subject</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Stats Grid -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div class="bg-white border border-zinc-200 rounded-lg p-6">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-zinc-600 text-sm font-medium uppercase tracking-wide">Current Streak</h3>
            <svg class="w-6 h-6 text-orange-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z"/>
            </svg>
          </div>
          <p class="text-4xl font-bold mb-2 text-black" x-text="user.streak + ' days'"></p>
          <p class="text-sm text-zinc-500">Keep it going</p>
        </div>

        <div class="bg-white border border-zinc-200 rounded-lg p-6">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-zinc-600 text-sm font-medium uppercase tracking-wide">Total XP</h3>
            <svg class="w-6 h-6 text-blue-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>
            </svg>
          </div>
          <p class="text-4xl font-bold mb-2 text-black" x-text="user.xp"></p>
          <p class="text-sm text-zinc-500">Rank #<span x-text="user.rank"></span> this week</p>
        </div>

        <div class="bg-white border border-zinc-200 rounded-lg p-6">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-zinc-600 text-sm font-medium uppercase tracking-wide">Study Buddies</h3>
            <svg class="w-6 h-6 text-zinc-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/>
              <circle cx="9" cy="7" r="4"/>
              <path d="M22 21v-2a4 4 0 0 0-3-3.87"/>
              <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
            </svg>
          </div>
          <p class="text-4xl font-bold mb-2 text-black" x-text="user.buddies"></p>
          <p class="text-sm text-blue-600 cursor-pointer hover:text-blue-700 transition-colors" @click="showInviteModal = true">Invite more +</p>
        </div>
      </div>

      <!-- Two Column Layout -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        
        <!-- Left Column - Activity Feed -->
        <div class="lg:col-span-2 space-y-6">
          
          <!-- Challenge Card -->
          <div class="bg-white border border-blue-500/30 rounded-lg p-6">
            <div class="flex items-start justify-between mb-4">
              <div class="flex items-start gap-3">
                <svg class="w-6 h-6 text-blue-600 mt-1" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="10"/>
                  <circle cx="12" cy="12" r="6"/>
                  <circle cx="12" cy="12" r="2"/>
                </svg>
                <div>
                  <h3 class="text-xl font-bold mb-2 text-black">Challenge a Friend</h3>
                  <p class="text-zinc-600">Beat their score and earn bonus XP</p>
                </div>
              </div>
              <a href="/challenge" class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors font-medium">
                Start Challenge
              </a>
            </div>
            <div class="flex items-center gap-3 text-sm text-zinc-500">
              <span class="flex items-center gap-1">
                <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/>
                  <path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/>
                  <path d="M4 22h16"/>
                  <path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/>
                  <path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/>
                  <path d="M18 2H6v7a6 6 0 0 0 12 0V2Z"/>
                </svg>
                Win: +50 XP
              </span>
              <span>•</span>
              <span class="flex items-center gap-1">
                <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10"/>
                </svg>
                Lose: Get a Streak Shield
              </span>
            </div>
          </div>

          <!-- Recent Activity -->
          <div class="bg-white border border-zinc-200 rounded-lg p-6">
            <h3 class="text-lg font-bold mb-4 text-black">Recent Activity</h3>
            <div class="space-y-4">
              <template x-for="activity in activities" :key="activity.id">
                <div class="flex items-start gap-4 p-4 bg-zinc-50 border border-zinc-200 rounded hover:border-zinc-300 transition-colors">
                  <img :src="activity.avatar" :alt="activity.user" class="w-10 h-10 rounded-full object-cover border border-zinc-300" />
                  <div class="flex-1">
                    <p class="text-sm">
                      <span class="font-semibold text-black" x-text="activity.user"></span>
                      <span class="text-zinc-600" x-text="' ' + activity.action"></span>
                    </p>
                    <p class="text-xs text-zinc-400" x-text="activity.time"></p>
                  </div>
                  <button x-show="activity.actionable" class="px-3 py-1 bg-white text-zinc-700 text-sm rounded hover:bg-zinc-50 transition-colors border border-zinc-300">
                    Challenge
                  </button>
                </div>
              </template>
            </div>
          </div>

        </div>

        <!-- Right Column - Leaderboard Preview -->
        <div class="space-y-6">
          <div class="bg-white border border-zinc-200 rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-bold text-black">Weekly Leaders</h3>
              <span class="text-sm text-zinc-500">This Week</span>
            </div>
            <div class="space-y-3">
              <template x-for="(leader, index) in leaderboard.slice(0, 5)" :key="leader.id">
                <div class="flex items-center gap-3 p-3 bg-zinc-50 border border-zinc-200 rounded">
                  <span class="text-lg font-bold w-6" x-text="index + 1" :class="index === 0 ? 'text-blue-600' : 'text-zinc-400'"></span>
                  <img :src="leader.avatar" :alt="leader.name" class="w-8 h-8 rounded-full object-cover border border-zinc-300" />
                  <div class="flex-1">
                    <p class="text-sm font-semibold text-black" x-text="leader.name"></p>
                    <p class="text-xs text-zinc-500" x-text="leader.xp + ' XP'"></p>
                  </div>
                </div>
              </template>
            </div>
          </div>

          <!-- Invite Card -->
          <div class="bg-white border border-zinc-200 rounded-lg p-6">
            <div class="flex items-center gap-2 mb-2">
              <svg class="w-5 h-5 text-blue-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <rect x="3" y="8" width="18" height="4" rx="1"/>
                <path d="M12 8v13"/>
                <path d="M19 12v7a2 2 0 0 0-2 2H7a2 2 0 0 1-2-2v-7"/>
                <path d="M7.5 8a2.5 2.5 0 0 1 0-5A4.8 8 0 0 1 12 8a4.8 8 0 0 1 4.5-5 2.5 2.5 0 0 1 0 5"/>
              </svg>
              <h3 class="text-lg font-bold text-black">Invite Friends</h3>
            </div>
            <p class="text-zinc-600 mb-4">Get 100 XP for each friend who joins</p>
            <button @click="showInviteModal = true" class="w-full px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors font-medium">
              Share Invite Link
            </button>
          </div>
        </div>

      </div>

    </main>

    <!-- Invite Modal -->
    <div x-show="showInviteModal" 
         x-cloak
         x-transition 
         class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4" 
         @click="showInviteModal = false">
      <div class="bg-white border border-zinc-200 rounded-lg p-8 max-w-md w-full" @click.stop>
        <div class="flex items-center gap-2 mb-4">
          <svg class="w-6 h-6 text-blue-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <rect x="3" y="8" width="18" height="4" rx="1"/>
            <path d="M12 8v13"/>
            <path d="M19 12v7a2 2 0 0 0-2 2H7a2 2 0 0 1-2-2v-7"/>
            <path d="M7.5 8a2.5 2.5 0 0 1 0-5A4.8 8 0 0 1 12 8a4.8 8 0 0 1 4.5-5 2.5 2.5 0 0 1 0 5"/>
          </svg>
          <h3 class="text-2xl font-bold text-black">Invite Friends</h3>
        </div>
        <p class="text-zinc-600 mb-6">Share your unique link and earn 100 XP for each friend who joins</p>
        
        <div class="bg-zinc-50 border border-zinc-200 rounded p-4 mb-4 flex items-center justify-between">
          <code class="text-sm text-blue-600">varsitytutors.com/join/alex123</code>
          <button class="px-3 py-1 bg-white text-zinc-700 text-sm rounded hover:bg-zinc-50 transition-colors border border-zinc-200">
            Copy
          </button>
        </div>

        <div class="flex gap-3 mb-6">
          <button class="flex-1 px-4 py-3 bg-zinc-50 text-zinc-700 rounded hover:bg-zinc-100 transition-colors border border-zinc-200">
            Share on Twitter
          </button>
          <button class="flex-1 px-4 py-3 bg-zinc-50 text-zinc-700 rounded hover:bg-zinc-100 transition-colors border border-zinc-200">
            Share on WhatsApp
          </button>
        </div>

        <button @click="showInviteModal = false" class="w-full px-4 py-3 bg-zinc-50 text-zinc-600 rounded hover:bg-zinc-100 transition-colors border border-zinc-200">
          Close
        </button>
      </div>
    </div>

  </div>
`

const jsContent = `
function app() {
  return {
    showInviteModal: false,
    
    user: {
      name: 'Alex',
      xp: 2450,
      streak: 12,
      rank: 8,
      buddies: 5
    },

    liveStats: {
      activeStudents: 28,
      sessionsToday: 156,
      trendingSubject: 'Calculus'
    },

    activities: [
      {
        id: 1,
        user: 'Sarah M.',
        action: 'completed a Math challenge and earned 50 XP',
        time: '2 min ago',
        avatar: '/diverse-student-girl.png',
        actionable: true
      },
      {
        id: 2,
        user: 'Mike R.',
        action: 'reached a 15-day streak!',
        time: '5 min ago',
        avatar: '/student-boy.png',
        actionable: false
      },
      {
        id: 3,
        user: 'Emma L.',
        action: 'challenged you to a Science quiz',
        time: '12 min ago',
        avatar: '/student-girl-2.jpg',
        actionable: true
      },
      {
        id: 4,
        user: 'James K.',
        action: 'scored 95% on English practice',
        time: '18 min ago',
        avatar: '/student-boy-2.jpg',
        actionable: true
      }
    ],

    leaderboard: [
      { id: 1, name: 'Sarah M.', xp: 3250, streak: 18, avatar: '/diverse-student-girl.png' },
      { id: 2, name: 'Mike R.', xp: 3100, streak: 15, avatar: '/student-boy.png' },
      { id: 3, name: 'Emma L.', xp: 2890, streak: 22, avatar: '/student-girl-2.jpg' },
      { id: 4, name: 'James K.', xp: 2750, streak: 10, avatar: '/student-boy-2.jpg' },
      { id: 5, name: 'Lisa P.', xp: 2680, streak: 14, avatar: '/student-girl-3.jpg' },
      { id: 6, name: 'Tom W.', xp: 2520, streak: 9, avatar: '/student-boy-3.jpg' },
      { id: 7, name: 'Nina S.', xp: 2480, streak: 16, avatar: '/student-girl-4.jpg' },
      { id: 8, name: 'Alex (You)', xp: 2450, streak: 12, avatar: '/student-avatar.png' }
    ]
  }
}
`
