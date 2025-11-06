"use client"

import { useEffect } from 'react';

export default function ChallengePage() {
  useEffect(() => {
    // Force Alpine to initialize after component mounts
    if (typeof window !== "undefined") {
      const script = document.createElement('script');
      script.src = 'https://unpkg.com/alpinejs@3.x.x/dist/cdn.min.js';
      script.defer = true;
      document.head.appendChild(script);
      
      script.onload = () => {
        if (window.Alpine) {
          window.Alpine.start();
        }
      };
    }
  }, []);

  return (
    <div className="min-h-screen bg-white" dangerouslySetInnerHTML={{ __html: htmlContent }} />
  )
}

const htmlContent = `
  <div x-data="challengeApp()" class="min-h-screen bg-white">
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
            <a href="/results" class="text-zinc-500 hover:text-black transition-colors">Results</a>
            <a href="/challenge" class="text-blue-600 font-medium transition-colors">Challenge</a>
          </nav>

          <div class="flex items-center gap-4">
            <div class="flex items-center gap-2 px-3 py-1.5 bg-zinc-50 border border-zinc-200 rounded-full">
              <span class="text-sm font-medium text-zinc-700">2450 XP</span>
            </div>
            <div class="w-10 h-10 rounded-full bg-zinc-100 border border-zinc-300 flex items-center justify-center font-bold">
              <img src="/student-avatar.png" alt="Profile" class="w-full h-full rounded-full object-cover" />
            </div>
          </div>
        </div>
      </div>
    </header>

    <!-- Challenge Content -->
    <main class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      
      <!-- Header -->
      <div class="text-center mb-8">
        <div class="flex justify-center mb-4">
          <svg class="w-16 h-16 text-blue-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="12" cy="12" r="10"/>
            <circle cx="12" cy="12" r="6"/>
            <circle cx="12" cy="12" r="2"/>
          </svg>
        </div>
        <h1 class="text-4xl font-bold mb-2 text-black">Challenge a Friend!</h1>
        <p class="text-xl text-zinc-600">Pick a subject and compete for bonus XP</p>
      </div>

      <!-- Challenge Info -->
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-6 mb-8">
        <div class="flex items-center justify-between flex-wrap gap-4">
          <div class="flex items-center gap-3">
            <svg class="w-8 h-8 text-blue-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/>
              <path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/>
              <path d="M4 22h16"/>
              <path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/>
              <path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/>
              <path d="M18 2H6v7a6 6 0 0 0 12 0V2Z"/>
            </svg>
            <div>
              <p class="font-bold text-black">Win Rewards</p>
              <p class="text-sm text-zinc-700">Beat their score: +50 XP</p>
            </div>
          </div>
          <div class="flex items-center gap-3">
            <svg class="w-8 h-8 text-blue-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10"/>
            </svg>
            <div>
              <p class="font-bold text-black">Lose Rewards</p>
              <p class="text-sm text-zinc-700">Get a Streak Shield</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Challenge Options -->
      <div class="space-y-4 mb-8">
        <h2 class="text-2xl font-bold mb-4 text-black">Choose Your Challenge</h2>
        
        <button @click="selectedChallenge = 'math'" :class="selectedChallenge === 'math' ? 'border-blue-600 bg-blue-50' : 'border-zinc-200 bg-white'" class="w-full p-6 border-2 rounded-lg text-left transition-all hover:border-blue-600/50">
          <div class="flex items-start justify-between">
            <div>
              <div class="flex items-center gap-3 mb-2">
                <svg class="w-8 h-8 text-blue-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <rect width="16" height="20" x="4" y="2" rx="2" ry="2"/>
                  <path d="M9 22v-4h6v4"/>
                  <path d="M8 6h.01"/>
                  <path d="M16 6h.01"/>
                  <path d="M12 6h.01"/>
                  <path d="M12 10h.01"/>
                  <path d="M12 14h.01"/>
                  <path d="M16 10h.01"/>
                  <path d="M16 14h.01"/>
                  <path d="M8 10h.01"/>
                  <path d="M8 14h.01"/>
                </svg>
                <h3 class="text-xl font-bold text-black">Math Challenge</h3>
              </div>
              <p class="text-zinc-600 mb-3">Algebra, Geometry, and Calculus questions</p>
              <div class="flex items-center gap-4 text-sm text-zinc-500">
                <span class="flex items-center gap-1">
                  <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <circle cx="12" cy="12" r="10"/>
                    <polyline points="12 6 12 12 16 14"/>
                  </svg>
                  10 minutes
                </span>
                <span>•</span>
                <span class="flex items-center gap-1">
                  <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z"/>
                    <polyline points="14 2 14 8 20 8"/>
                  </svg>
                  20 questions
                </span>
                <span>•</span>
                <span class="flex items-center gap-1">
                  <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>
                  </svg>
                  +50 XP
                </span>
              </div>
            </div>
            <div x-show="selectedChallenge === 'math'" class="text-blue-600 text-2xl">✓</div>
          </div>
        </button>

        <button @click="selectedChallenge = 'science'" :class="selectedChallenge === 'science' ? 'border-blue-600 bg-blue-50' : 'border-zinc-200 bg-white'" class="w-full p-6 border-2 rounded-lg text-left transition-all hover:border-blue-600/50">
          <div class="flex items-start justify-between">
            <div>
              <div class="flex items-center gap-3 mb-2">
                <svg class="w-8 h-8 text-blue-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M10 2v7.527a2 2 0 0 1-.211.896L4.72 20.55a1 1 0 0 0 .9 1.45h12.76a1 1 0 0 0 .9-1.45l-5.069-10.127A2 2 0 0 1 14 9.527V2"/>
                  <path d="M8.5 2h7"/>
                  <path d="M7 16h10"/>
                </svg>
                <h3 class="text-xl font-bold text-black">Science Challenge</h3>
              </div>
              <p class="text-zinc-600 mb-3">Biology, Chemistry, and Physics questions</p>
              <div class="flex items-center gap-4 text-sm text-zinc-500">
                <span class="flex items-center gap-1">
                  <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <circle cx="12" cy="12" r="10"/>
                    <polyline points="12 6 12 12 16 14"/>
                  </svg>
                  10 minutes
                </span>
                <span>•</span>
                <span class="flex items-center gap-1">
                  <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z"/>
                    <polyline points="14 2 14 8 20 8"/>
                  </svg>
                  20 questions
                </span>
                <span>•</span>
                <span class="flex items-center gap-1">
                  <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>
                  </svg>
                  +50 XP
                </span>
              </div>
            </div>
            <div x-show="selectedChallenge === 'science'" class="text-blue-600 text-2xl">✓</div>
          </div>
        </button>

        <button @click="selectedChallenge = 'english'" :class="selectedChallenge === 'english' ? 'border-blue-600 bg-blue-50' : 'border-zinc-200 bg-white'" class="w-full p-6 border-2 rounded-lg text-left transition-all hover:border-blue-600/50">
          <div class="flex items-start justify-between">
            <div>
              <div class="flex items-center gap-3 mb-2">
                <svg class="w-8 h-8 text-blue-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/>
                  <path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/>
                </svg>
                <h3 class="text-xl font-bold text-black">English Challenge</h3>
              </div>
              <p class="text-zinc-600 mb-3">Grammar, vocabulary, and reading comprehension</p>
              <div class="flex items-center gap-4 text-sm text-zinc-500">
                <span class="flex items-center gap-1">
                  <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <circle cx="12" cy="12" r="10"/>
                    <polyline points="12 6 12 12 16 14"/>
                  </svg>
                  10 minutes
                </span>
                <span>•</span>
                <span class="flex items-center gap-1">
                  <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z"/>
                    <polyline points="14 2 14 8 20 8"/>
                  </svg>
                  20 questions
                </span>
                <span>•</span>
                <span class="flex items-center gap-1">
                  <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>
                  </svg>
                  +50 XP
                </span>
              </div>
            </div>
            <div x-show="selectedChallenge === 'english'" class="text-blue-600 text-2xl">✓</div>
          </div>
        </button>
      </div>

      <!-- Friend Selection -->
      <div class="bg-white border border-zinc-200 rounded-lg p-6 mb-8">
        <h3 class="text-xl font-bold mb-4 text-black">Select a Friend to Challenge</h3>
        <div class="space-y-3">
          <template x-for="friend in friends" :key="friend.id">
            <button @click="selectedFriend = friend.id" :class="selectedFriend === friend.id ? 'border-blue-600 bg-blue-50' : 'border-zinc-200 bg-zinc-50'" class="w-full flex items-center gap-4 p-4 border-2 rounded-lg hover:border-blue-600/50 transition-all">
              <img :src="friend.avatar" :alt="friend.name" class="w-12 h-12 rounded-full object-cover border border-zinc-300" />
              <div class="flex-1 text-left">
                <p class="font-semibold text-black" x-text="friend.name"></p>
                <p class="text-sm text-zinc-600" x-text="friend.xp + ' XP • ' + friend.streak + ' day streak'"></p>
              </div>
              <div x-show="selectedFriend === friend.id" class="text-blue-600 text-xl">✓</div>
            </button>
          </template>
        </div>
      </div>

      <!-- Generate Link -->
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-8">
        <h3 class="text-xl font-bold mb-4 text-black">Share Challenge Link</h3>
        <p class="text-zinc-700 mb-6">Send this link to your friend to start the challenge!</p>
        
        <div class="bg-white border border-zinc-200 rounded-lg p-4 mb-4 flex items-center justify-between">
          <code class="text-sm text-blue-600 flex-1 overflow-hidden text-ellipsis">varsitytutors.com/challenge/math-alex-vs-sarah</code>
          <button class="px-4 py-2 bg-zinc-50 text-zinc-700 rounded-lg hover:bg-zinc-100 transition-colors ml-3 border border-zinc-200">
            Copy Link
          </button>
        </div>

        <div class="flex gap-3">
          <button class="flex-1 px-4 py-3 bg-zinc-50 text-zinc-700 rounded-lg hover:bg-zinc-100 transition-colors border border-zinc-200">
            Share on Twitter
          </button>
          <button class="flex-1 px-4 py-3 bg-zinc-50 text-zinc-700 rounded-lg hover:bg-zinc-100 transition-colors border border-zinc-200">
            Share on WhatsApp
          </button>
          <button class="flex-1 px-4 py-3 bg-zinc-50 text-zinc-700 rounded-lg hover:bg-zinc-100 transition-colors border border-zinc-200">
            Share on Instagram
          </button>
        </div>
      </div>

      <!-- Back Button -->
      <div class="mt-8 text-center">
        <a href="/" class="inline-block px-8 py-3 bg-zinc-100 text-zinc-700 rounded-lg hover:bg-zinc-200 transition-colors border border-zinc-200">
          Back to Dashboard
        </a>
      </div>

    </main>
  </div>
`

const jsContent = `
function challengeApp() {
  return {
    selectedChallenge: 'math',
    selectedFriend: 1,
    
    friends: [
      { id: 1, name: 'Sarah M.', xp: 3250, streak: 18, avatar: '/diverse-student-girl.png' },
      { id: 2, name: 'Mike R.', xp: 3100, streak: 15, avatar: '/student-boy.png' },
      { id: 3, name: 'Emma L.', xp: 2890, streak: 22, avatar: '/student-girl-2.jpg' },
      { id: 4, name: 'James K.', xp: 2750, streak: 10, avatar: '/student-boy-2.jpg' }
    ]
  }
}
`
