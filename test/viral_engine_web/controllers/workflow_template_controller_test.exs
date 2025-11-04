defmodule ViralEngineWeb.WorkflowTemplateControllerTest do
  use ViralEngineWeb.ConnCase, async: true
  alias ViralEngine.WorkflowTemplateContext

  describe "POST /api/workflow-templates" do
    test "creates a template from workflow", %{conn: conn} do
      # Create a workflow first
      {:ok, workflow} =
        ViralEngine.WorkflowContext.create_workflow("Test Workflow", %{"step" => 1})

      params = %{
        "workflow_id" => workflow.id,
        "name" => "Template from Workflow",
        "description" => "Created from existing workflow",
        "is_public" => true,
        "created_by" => "user123"
      }

      conn = post(conn, "/api/workflow-templates", params)

      response = json_response(conn, 201)
      assert response["name"] == "Template from Workflow"
      assert response["description"] == "Created from existing workflow"
      assert response["is_public"] == true
      assert response["created_by"] == "user123"
      assert response["version"] == 1
    end

    test "creates a template directly", %{conn: conn} do
      params = %{
        "name" => "Direct Template",
        "description" => "Created directly",
        "template_data" => %{"state" => %{"step" => 1}},
        "is_public" => false,
        "created_by" => "user456"
      }

      conn = post(conn, "/api/workflow-templates", params)

      response = json_response(conn, 201)
      assert response["name"] == "Direct Template"
      assert response["is_public"] == false
      assert response["created_by"] == "user456"
    end

    test "returns error for invalid data", %{conn: conn} do
      params = %{"name" => "", "template_data" => %{}}

      conn = post(conn, "/api/workflow-templates", params)

      assert %{"errors" => %{"name" => ["can't be blank"]}} = json_response(conn, 422)
    end
  end

  describe "GET /api/workflow-templates" do
    test "lists all templates", %{conn: conn} do
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

      conn = get(conn, "/api/workflow-templates")

      response = json_response(conn, 200)
      assert length(response["templates"]) == 2
    end

    test "filters templates by created_by", %{conn: conn} do
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

      conn = get(conn, "/api/workflow-templates?created_by=user1")

      response = json_response(conn, 200)
      assert length(response["templates"]) == 1
      assert hd(response["templates"])["created_by"] == "user1"
    end
  end

  describe "GET /api/workflow-templates/public" do
    test "returns only public templates", %{conn: conn} do
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

      conn = get(conn, "/api/workflow-templates/public")

      response = json_response(conn, 200)
      assert length(response["templates"]) == 1
      assert hd(response["templates"])["name"] == "Public Template"
    end
  end

  describe "GET /api/workflow-templates/:id" do
    test "returns template details", %{conn: conn} do
      {:ok, template} =
        WorkflowTemplateContext.create_template(%{
          name: "Test Template",
          description: "Test description",
          template_data: %{"state" => %{"step" => 1}},
          created_by: "user1"
        })

      conn = get(conn, "/api/workflow-templates/#{template.id}")

      response = json_response(conn, 200)
      assert response["id"] == template.id
      assert response["name"] == "Test Template"
      assert response["description"] == "Test description"
      assert response["template_data"]["state"]["step"] == 1
    end

    test "returns 404 for non-existent template", %{conn: conn} do
      conn = get(conn, "/api/workflow-templates/999")

      assert %{"error" => "Template not found"} = json_response(conn, 404)
    end
  end

  describe "PUT /api/workflow-templates/:id" do
    test "updates template", %{conn: conn} do
      {:ok, template} =
        WorkflowTemplateContext.create_template(%{
          name: "Original Name",
          template_data: %{},
          created_by: "user1"
        })

      params = %{
        "name" => "Updated Name",
        "description" => "Updated description",
        "is_public" => true
      }

      conn = put(conn, "/api/workflow-templates/#{template.id}", params)

      response = json_response(conn, 200)
      assert response["name"] == "Updated Name"
      assert response["description"] == "Updated description"
      assert response["is_public"] == true
      assert response["version"] == 2
    end
  end

  describe "DELETE /api/workflow-templates/:id" do
    test "deletes template", %{conn: conn} do
      {:ok, template} =
        WorkflowTemplateContext.create_template(%{
          name: "Template to Delete",
          template_data: %{},
          created_by: "user1"
        })

      conn = delete(conn, "/api/workflow-templates/#{template.id}")

      assert response(conn, 204)

      # Verify it's deleted
      conn = get(conn, "/api/workflow-templates/#{template.id}")
      assert %{"error" => "Template not found"} = json_response(conn, 404)
    end
  end

  describe "POST /api/workflows/from-template/:id" do
    test "instantiates workflow from template", %{conn: conn} do
      {:ok, template} =
        WorkflowTemplateContext.create_template(%{
          name: "Test Template",
          template_data: %{
            "state" => %{"step" => 1, "message" => "Hello {{user_name}}"}
          },
          created_by: "user1"
        })

      params = %{
        "variables" => %{
          "user_name" => "Alice",
          "workflow_name" => "Custom Workflow"
        }
      }

      conn = post(conn, "/api/workflows/from-template/#{template.id}", params)

      response = json_response(conn, 201)
      assert response["name"] == "Custom Workflow"
      assert response["state"]["step"] == 1
      assert response["state"]["message"] == "Hello Alice"
    end

    test "instantiates workflow with default name", %{conn: conn} do
      {:ok, template} =
        WorkflowTemplateContext.create_template(%{
          name: "Test Template",
          template_data: %{"state" => %{"step" => 1}},
          created_by: "user1"
        })

      conn = post(conn, "/api/workflows/from-template/#{template.id}", %{})

      response = json_response(conn, 201)
      assert response["name"] == "Test Template (from template)"
    end

    test "returns 404 for non-existent template", %{conn: conn} do
      conn = post(conn, "/api/workflows/from-template/999", %{})

      assert %{"error" => "Template not found"} = json_response(conn, 404)
    end
  end
end
