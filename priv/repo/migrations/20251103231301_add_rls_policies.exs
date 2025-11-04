defmodule ViralEngine.Repo.Migrations.AddRlsPolicies do
  use Ecto.Migration

  def change do
    # Enable RLS on all tenant-scoped tables
    execute("ALTER TABLE organizations ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE tasks ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE workflows ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE agents ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE benchmarks ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE alerts ENABLE ROW LEVEL SECURITY")
    execute("ALTER TABLE metrics ENABLE ROW LEVEL SECURITY")

    # Create RLS policies for organizations table
    # Organizations can be accessed by their own tenant_id
    execute("""
    CREATE POLICY organizations_tenant_policy ON organizations
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
    """)

    # Create RLS policies for tasks table
    execute("""
    CREATE POLICY tasks_tenant_policy ON tasks
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
    """)

    # Create RLS policies for workflows table
    execute("""
    CREATE POLICY workflows_tenant_policy ON workflows
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
    """)

    # Create RLS policies for agents table
    execute("""
    CREATE POLICY agents_tenant_policy ON agents
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
    """)

    # Create RLS policies for benchmarks table
    execute("""
    CREATE POLICY benchmarks_tenant_policy ON benchmarks
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
    """)

    # Create RLS policies for alerts table
    execute("""
    CREATE POLICY alerts_tenant_policy ON alerts
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
    """)

    # Create RLS policies for metrics table
    execute("""
    CREATE POLICY metrics_tenant_policy ON metrics
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
    """)
  end
end
