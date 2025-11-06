import Config

# AI Provider Configuration for Vel Tutor
# This file configures all AI providers (OpenAI, Groq, Perplexity) and routing logic

config :viral_engine, :ai,
  # Default provider for new requests (recommended: :groq for cost savings)
  default_provider: :groq,

  # Provider configurations
  providers: %{
    openai: %{
      # Enable/disable this provider
      enabled: true,

      # Environment variable containing API key
      api_key_env: "OPENAI_API_KEY",

      # Available models for this provider
      models: ["gpt-5", "gpt-4o-mini", "gpt-4-turbo"],

      # Default model if not specified
      default_model: "gpt-5",

      # Request timeout in milliseconds
      timeout: 30_000,

      # Maximum retry attempts on failure
      max_retries: 3,

      # Cost per 1M tokens (approximate, for tracking)
      cost_per_1m_tokens: %{
        "gpt-5" => 6.25,
        "gpt-4o-mini" => 0.37,
        "gpt-4-turbo" => 5.00
      },

      # Average latency in milliseconds (for routing decisions)
      avg_latency_ms: 2100,

      # Reliability score (0.0-1.0, for routing decisions)
      reliability_score: 0.98
    },
    groq: %{
      enabled: true,
      api_key_env: "GROQ_API_KEY",
      models: [
        "llama-3.3-70b-versatile",
        "llama-3.1-70b-versatile",
        "mixtral-8x7b-32768"
      ],
      default_model: "llama-3.3-70b-versatile",
      timeout: 10_000,
      max_retries: 3,
      cost_per_1m_tokens: %{
        "llama-3.3-70b-versatile" => 0.69,
        "llama-3.1-70b-versatile" => 0.59,
        "mixtral-8x7b-32768" => 0.24
      },
      avg_latency_ms: 300,
      reliability_score: 0.95
    },
    perplexity: %{
      enabled: true,
      api_key_env: "PERPLEXITY_API_KEY",
      models: ["sonar-large-online", "sonar-medium-online", "sonar-small-online"],
      default_model: "sonar-large-online",
      timeout: 30_000,
      max_retries: 3,
      cost_per_1m_tokens: %{
        "sonar-large-online" => 1.0,
        "sonar-medium-online" => 0.6,
        "sonar-small-online" => 0.2
      },
      avg_latency_ms: 3200,
      reliability_score: 0.96,
      # Perplexity-specific: cache research results for 24 hours
      cache_ttl: 86_400
    }
  },

  # Task-based routing rules
  # Specifies which provider/model to use for each task type
  routing: %{
    # Code generation: Fast, cheap, good for coding tasks
    code_generation: %{provider: :groq, model: "llama-3.3-70b-versatile"},

    # Planning & architecture: Best reasoning capabilities
    planning: %{provider: :openai, model: "gpt-5"},

    # Research: Web-connected, real-time data access
    research: %{provider: :perplexity, model: "sonar-large-online"},

    # Validation & review: Fast, cheap validation
    validation: %{provider: :groq, model: "mixtral-8x7b-32768"},

    # General purpose: Balanced cost/performance
    general: %{provider: :groq, model: "llama-3.3-70b-versatile"}
  },

  # Fallback provider chains
  # If primary provider fails, try these providers in order
  fallback: %{
    openai: [:groq, :perplexity],
    groq: [:openai, :perplexity],
    perplexity: [:openai, :groq]
  },

  # Cost control settings
  cost_control: %{
    # Daily budget in USD (set to nil to disable)
    daily_budget: 50.0,

    # Alert when reaching this percentage of budget
    alert_threshold: 0.8,

    # Hard stop when budget exceeded (if false, only logs warning)
    hard_limit: true,

    # Track costs per provider
    track_by_provider: true,

    # Track costs per user (if user_id provided in requests)
    track_by_user: false
  },

  # Circuit breaker settings (prevent cascade failures)
  circuit_breaker: %{
    # Open circuit after this many consecutive failures
    failure_threshold: 5,

    # Keep circuit open for this many seconds
    timeout: 60,

    # Allow one request through after timeout to test recovery
    half_open_max_calls: 1
  },

  # Caching settings (reduce redundant API calls)
  caching: %{
    # Enable request/response caching
    enabled: true,

    # Cache TTL in seconds (default 1 hour)
    ttl: 3600,

    # Maximum cache size in MB
    max_size_mb: 100,

    # Cache identical prompts across users (be careful with PII)
    cache_across_users: false
  },

  # Monitoring and observability
  monitoring: %{
    # Log all AI requests (can be verbose, disable in production)
    log_requests: true,

    # Log request/response details (disable in production for PII)
    log_details: false,

    # Track metrics (latency, cost, tokens, errors)
    track_metrics: true,

    # Send metrics to telemetry
    telemetry_enabled: true,

    # Alert on repeated failures
    alert_on_failures: true
  }

# Environment-specific overrides
if config_env() == :prod do
  config :viral_engine, :ai,
    # Production: Prefer reliability over cost
    default_provider: :openai,
    # Don't log detailed request/response in production (PII concerns)
    monitoring: %{
      log_requests: true,
      log_details: false,
      track_metrics: true,
      telemetry_enabled: true,
      alert_on_failures: true
    }
end

if config_env() == :test do
  config :viral_engine, :ai,
    # Test: Use mock providers or cheap models
    default_provider: :groq,
    providers: %{
      openai: %{enabled: false},
      groq: %{enabled: true, default_model: "llama-3.3-70b-versatile"},
      perplexity: %{enabled: false}
    },
    # Disable caching in tests for predictability
    caching: %{enabled: false}
end
