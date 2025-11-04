defmodule ViralEngine.WorkflowTemplateContextTest do
  use ViralEngine.DataCase
  alias ViralEngine.WorkflowTemplateContext

  describe "create_template/1" do
    test "creates a template successfully" do
      attrs = %{
        name: "Test Template",
        description: "A test template",
        template_data: %{"step" => 1},
        created_by: "user123"
      }

      {:ok, template} = WorkflowTemplateContext.create_template(attrs)

      assert template.name == "Test Template"
      assert template.description == "A test template"
      assert template.template_data == %{"step" => 1}
      assert template.created_by == "user123"
      assert template.version == 1
      assert template.is_public == false
    end

    test "returns error for invalid data" do
      attrs = %{name: "", template_data: %{}, created_by: "user123"}

      {:error, changeset} = WorkflowTemplateContext.create_template(attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "get_template/1" do
    test "returns template when found" do
      attrs = %{
        name: "Test Template",
        template_data: %{"step" => 1},
        created_by: "user123"
      }

      {:ok, template} = WorkflowTemplateContext.create_template(attrs)

      {:ok, found_template} = WorkflowTemplateContext.get_template(template.id)
      assert found_template.id == template.id
    end

    test "returns error when not found" do
      assert {:error, :not_found} = WorkflowTemplateContext.get_template(999)
    end
  end

  describe "list_templates/1" do
    test "lists all templates" do
      {:ok, _} =
        WorkflowTemplateContext.create_template(%{
          name: "Template 1",
          template_data: %{},
          created_by: "user1"
        })

      {:ok, _} =
        WorkflowTemplateContext.create_template(%{
          name: "Template 2",
          template_data: %{},
          created_by: "user2"
        })

      templates = WorkflowTemplateContext.list_templates()
      assert length(templates) == 2
    end

    test "filters by created_by" do
      {:ok, _} =
        WorkflowTemplateContext.create_template(%{
          name: "Template 1",
          template_data: %{},
          created_by: "user1"
        })

      {:ok, _} =
        WorkflowTemplateContext.create_template(%{
          name: "Template 2",
          template_data: %{},
          created_by: "user2"
        })

      templates = WorkflowTemplateContext.list_templates(%{created_by: "user1"})
      assert length(templates) == 1
      assert hd(templates).created_by == "user1"
    end

    test "filters by name_contains" do
      {:ok, _} =
        WorkflowTemplateContext.create_template(%{
          name: "Approval Template",
          template_data: %{},
          created_by: "user1"
        })

      {:ok, _} =
        WorkflowTemplateContext.create_template(%{
          name: "Review Template",
          template_data: %{},
          created_by: "user1"
        })

      templates = WorkflowTemplateContext.list_templates(%{name_contains: "Approval"})
      assert length(templates) == 1
      assert hd(templates).name == "Approval Template"
    end
  end

  describe "list_public_templates/0" do
    test "returns only public templates" do
      {:ok, _} =
        WorkflowTemplateContext.create_template(%{
          name: "Public Template",
          template_data: %{},
          created_by: "user1",
          is_public: true
        })

      {:ok, _} =
        WorkflowTemplateContext.create_template(%{
          name: "Private Template",
          template_data: %{},
          created_by: "user1",
          is_public: false
        })

      public_templates = WorkflowTemplateContext.list_public_templates()
      assert length(public_templates) == 1
      assert hd(public_templates).name == "Public Template"
    end
  end

  describe "update_template/2" do
    test "updates template and increments version" do
      {:ok, template} =
        WorkflowTemplateContext.create_template(%{
          name: "Original Name",
          template_data: %{},
          created_by: "user1"
        })

      {:ok, updated_template} =
        WorkflowTemplateContext.update_template(template.id, %{
          name: "Updated Name",
          description: "Updated description"
        })

      assert updated_template.name == "Updated Name"
      assert updated_template.description == "Updated description"
      assert updated_template.version == 2
    end

    test "returns error for non-existent template" do
      assert {:error, :not_found} =
               WorkflowTemplateContext.update_template(999, %{name: "New Name"})
    end
  end

  describe "delete_template/1" do
    test "deletes template successfully" do
      {:ok, template} =
        WorkflowTemplateContext.create_template(%{
          name: "Template to Delete",
          template_data: %{},
          created_by: "user1"
        })

      {:ok, _} = WorkflowTemplateContext.delete_template(template.id)

      assert {:error, :not_found} = WorkflowTemplateContext.get_template(template.id)
    end

    test "returns error for non-existent template" do
      assert {:error, :not_found} = WorkflowTemplateContext.delete_template(999)
    end
  end

  describe "create_template_from_workflow/2" do
    test "creates template from existing workflow" do
      # Create a workflow first
      {:ok, workflow} =
        ViralEngine.WorkflowContext.create_workflow("Test Workflow", %{"step" => 1})

      # Create template from workflow
      template_attrs = %{
        name: "Workflow Template",
        description: "Created from workflow",
        is_public: true,
        created_by: "user1"
      }

      {:ok, template} =
        WorkflowTemplateContext.create_template_from_workflow(workflow.id, template_attrs)

      assert template.name == "Workflow Template"
      assert template.template_data["name"] == "Test Workflow"
      assert template.template_data["state"] == %{"step" => 1}
      assert template.is_public == true
    end

    test "returns error for non-existent workflow" do
      template_attrs = %{name: "Template", created_by: "user1"}

      assert {:error, :workflow_not_found} =
               WorkflowTemplateContext.create_template_from_workflow(999, template_attrs)
    end
  end

  describe "instantiate_workflow/2" do
    test "instantiates workflow from template" do
      # Create template
      {:ok, template} =
        WorkflowTemplateContext.create_template(%{
          name: "Test Template",
          template_data: %{
            "state" => %{"step" => 1, "message" => "Hello {{user_name}}"},
            "routing_rules" => [],
            "conditions" => []
          },
          created_by: "user1"
        })

      # Instantiate with variables
      variables = %{"user_name" => "Alice", "workflow_name" => "Custom Workflow"}

      {:ok, workflow} = WorkflowTemplateContext.instantiate_workflow(template.id, variables)

      assert workflow.name == "Custom Workflow"
      assert workflow.state["step"] == 1
      assert workflow.state["message"] == "Hello Alice"
    end

    test "instantiates workflow with default name when no variables provided" do
      {:ok, template} =
        WorkflowTemplateContext.create_template(%{
          name: "Test Template",
          template_data: %{"state" => %{"step" => 1}},
          created_by: "user1"
        })

      {:ok, workflow} = WorkflowTemplateContext.instantiate_workflow(template.id)

      assert workflow.name == "Test Template (from template)"
    end

    test "returns error for non-existent template" do
      assert {:error, :template_not_found} = WorkflowTemplateContext.instantiate_workflow(999)
    end
  end

  describe "variable substitution" do
    test "substitutes variables in strings" do
      data = "Hello {{user_name}}, welcome to {{app_name}}!"
      variables = %{"user_name" => "Alice", "app_name" => "MyApp"}

      result = WorkflowTemplateContext.substitute_variables(data, variables)
      assert result == "Hello Alice, welcome to MyApp!"
    end

    test "leaves unsubstituted variables as placeholders" do
      data = "Hello {{user_name}}, welcome!"
      variables = %{}

      result = WorkflowTemplateContext.substitute_variables(data, variables)
      assert result == "Hello {{user_name}}, welcome!"
    end

    test "substitutes variables in nested maps" do
      data = %{
        "message" => "Hello {{user_name}}",
        "config" => %{
          "title" => "{{app_name}} Dashboard",
          "items" => ["{{item1}}", "{{item2}}"]
        }
      }

      variables = %{
        "user_name" => "Bob",
        "app_name" => "MyApp",
        "item1" => "Reports",
        "item2" => "Analytics"
      }

      result = WorkflowTemplateContext.substitute_variables(data, variables)

      assert result["message"] == "Hello Bob"
      assert result["config"]["title"] == "MyApp Dashboard"
      assert result["config"]["items"] == ["Reports", "Analytics"]
    end
  end
end
