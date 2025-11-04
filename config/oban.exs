import Config

# Oban Configuration for Viral Engine
# Optimized queue configuration for performance reports and email delivery

config :viral_engine, Oban,
  repo: ViralEngine.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       # Generate weekly performance reports every Monday at 9 AM
       {"0 9 * * 1", ViralEngine.Workers.PerformanceReportWorker, args: %{type: "weekly"}},
       # Generate monthly reports on 1st of month at 10 AM
       {"0 10 1 * *", ViralEngine.Workers.PerformanceReportWorker, args: %{type: "monthly"}}
     ]}
  ],
  queues: [
    # Performance report generation (CPU intensive)
    reports: [limit: 5, paused: false],

    # Email delivery (I/O bound, higher concurrency)
    email: [limit: 10, paused: false],

    # Default queue for other jobs
    default: [limit: 3, paused: false]
  ]

# Retry configuration
config :viral_engine, ViralEngine.Workers.PerformanceReportWorker,
  max_attempts: 3,
  priority: 1,
  queue: :reports

config :viral_engine, ViralEngine.Workers.EmailDeliveryWorker,
  max_attempts: 5,
  priority: 2,
  queue: :email
