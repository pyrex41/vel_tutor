defmodule ViralEngineWeb.Router do
  use ViralEngineWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
    plug(ViralEngineWeb.Plugs.TenantContextPlug)
    plug(ViralEngineWeb.Plugs.RateLimitPlug)
  end

  scope "/api", ViralEngineWeb do
    pipe_through(:api)

    # Health check (public)
    get("/health", HealthController, :index)

    # Organization management
    post("/organizations", OrganizationController, :create)
    get("/organizations", OrganizationController, :index)
    get("/organizations/:id", OrganizationController, :show)
    put("/organizations/:id", OrganizationController, :update)
    delete("/organizations/:id", OrganizationController, :delete)

    # Task management
    post("/tasks", TaskController, :create)
    get("/tasks", TaskController, :index)
    get("/tasks/:id", TaskController, :show)
    get("/tasks/:id/stream", TaskController, :stream)
    get("/tasks/:id/stream-response", TaskController, :stream_response)
    post("/tasks/:id/cancel", TaskController, :cancel)

    # Batch operations
    post("/batches", BatchController, :create)
    get("/batches", BatchController, :index)
    get("/batches/:id", BatchController, :show)
    post("/batches/:id/cancel", BatchController, :cancel)
    get("/batches/:id/results", BatchController, :export_results)

    # Webhook notifications
    post("/webhooks", WebhooksController, :create)
    get("/webhooks", WebhooksController, :index)
    get("/webhooks/:id", WebhooksController, :show)
    put("/webhooks/:id", WebhooksController, :update)
    delete("/webhooks/:id", WebhooksController, :delete)
    post("/webhooks/:id/test", WebhooksController, :test)
    get("/webhooks/:id/deliveries", WebhooksController, :deliveries)

    # Agent configuration
    post("/agents", AgentConfigController, :create)
    put("/agents/:id", AgentConfigController, :update)
    delete("/agents/:id", AgentConfigController, :delete)
    post("/agents/:id/test", AgentConfigController, :test)

    # RBAC management
    put("/users/:user_id/roles", RolesController, :assign_role)
    delete("/users/:user_id/roles/:role_id", RolesController, :revoke_role)
    get("/users/:user_id/roles", RolesController, :get_user_roles)
    get("/users/:user_id/permissions/check", RolesController, :check_permission)
    get("/roles", RolesController, :index_roles)
    get("/permissions", RolesController, :index_permissions)

    # Rate limit management
    put("/users/:id/rate-limits", UserController, :update_rate_limits)
    get("/users/:id/rate-limits", UserController, :show_rate_limits)
    delete("/users/:id/rate-limits", UserController, :delete_rate_limits)

    # Workflow management
    post("/workflows", WorkflowController, :create)
    get("/workflows/:id", WorkflowController, :show)
    put("/workflows/:id/advance", WorkflowController, :advance)
    post("/workflows/:id/rules", WorkflowController, :add_rule)
    post("/workflows/:id/conditions", WorkflowController, :add_condition)
    get("/workflows/:id/visualize", WorkflowController, :visualize)

    # Approval gates
    post("/workflows/:id/gates", WorkflowController, :add_gate)
    put("/workflows/:id/pause", WorkflowController, :pause)
    post("/workflows/:id/approve", WorkflowController, :approve)
    post("/workflows/:id/timeout", WorkflowController, :check_timeout)

    # Parallel execution
    post("/workflows/:id/parallel-groups", WorkflowController, :add_parallel_group)
    post("/workflows/:id/execute-parallel", WorkflowController, :execute_parallel)

    # Error handling and recovery
    post("/workflows/:id/retry-from-step/:step_id", WorkflowController, :retry_from_step)

    # Workflow templates
    post("/workflow-templates", WorkflowTemplateController, :create)
    get("/workflow-templates", WorkflowTemplateController, :index)
    get("/workflow-templates/public", WorkflowTemplateController, :public)
    get("/workflow-templates/:id", WorkflowTemplateController, :show)
    put("/workflow-templates/:id", WorkflowTemplateController, :update)
    delete("/workflow-templates/:id", WorkflowTemplateController, :delete)
    post("/workflows/from-template/:id", WorkflowTemplateController, :instantiate)

    # Fine-tuning jobs
    post("/fine-tuning-jobs", FineTuningController, :create)
    get("/fine-tuning-jobs", FineTuningController, :index)
    get("/fine-tuning-jobs/:id", FineTuningController, :show)
    post("/fine-tuning-jobs/:id/register", FineTuningController, :register_model)
    delete("/fine-tuning-jobs/:id", FineTuningController, :delete)

    # Admin - Audit Logs
    get("/admin/audit_logs", AdminController, :audit_logs)
    get("/admin/audit_logs/stats", AdminController, :audit_logs_stats)
  end

  scope "/mcp", ViralEngineWeb do
    pipe_through(:api)

    # MCP agent endpoints
    post("/:agent/:method", AgentController, :call_agent)
    get("/:agent/health", AgentController, :health)
  end

  # Practice session routes
  live("/practice", PracticeSessionLive)
  live("/practice/results/:id", PracticeResultsLive)

  # Diagnostic assessment routes
  live("/diagnostic", DiagnosticAssessmentLive)
  live("/diagnostic/:id", DiagnosticAssessmentLive)
  live("/diagnostic/results/:id", DiagnosticResultsLive)

  # Flashcard study routes
  live("/flashcards", FlashcardStudyLive)
  live("/flashcards/study/:deck_id", FlashcardStudyLive)

  # Dashboard routes
  scope "/dashboard", ViralEngineWeb do
    pipe_through([:fetch_session, :protect_from_forgery])

    live("/presence", PresenceLive, :index)
    live("/presence", PresenceLive, :index)
    live("/performance", PerformanceDashboardLive)
    live("/costs", CostDashboardLive)
    live("/alerts", AlertDashboardLive)
    live("/tasks", TaskExecutionHistoryLive)
    live("/benchmarks", BenchmarksLive)
    live("/rate-limits", RateLimitsLive)
  end

  # Enable LiveDashboard in development
  if Mix.env() == :dev do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through([:fetch_session, :protect_from_forgery])
      live_dashboard("/dashboard/phoenix", metrics: ViralEngineWeb.Telemetry)
    end
  end
end
