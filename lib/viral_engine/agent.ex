defmodule ViralEngine.Agent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "agents" do
    field(:tenant_id, Ecto.UUID)
    field(:name, :string)
    field(:config, :map)
    field(:metadata, :map)
    field(:user_id, :integer)
    field(:fine_tuned_model_id, :string)
    field(:deleted_at, :naive_datetime)

    timestamps()
  end

  def changeset(agent, attrs) do
    agent
    |> cast(attrs, [
      :tenant_id,
      :name,
      :config,
      :metadata,
      :user_id,
      :fine_tuned_model_id,
      :deleted_at
    ])
    |> validate_required([:tenant_id, :name, :config, :user_id])
    |> validate_config()
  end

  defp validate_config(changeset) do
    config = get_field(changeset, :config)

    if config do
      validate_config_fields(changeset, config)
    else
      changeset
    end
  end

  defp validate_config_fields(changeset, config) do
    if config do
      provider = config["provider"]
      temperature = config["temperature"]
      max_tokens = config["max_tokens"]
      system_prompt = config["system_prompt"]
      fine_tuned_model_id = get_field(changeset, :fine_tuned_model_id)

      errors = []

      # Validate provider
      errors =
        if provider not in ["openai", "groq", "perplexity"],
          do: [{:provider, "must be openai, groq, or perplexity"} | errors],
          else: errors

      # If using fine-tuned model, must be OpenAI
      errors =
        if fine_tuned_model_id && provider != "openai",
          do: [{:fine_tuned_model_id, "can only be used with OpenAI provider"} | errors],
          else: errors

      # Validate temperature
      errors =
        if temperature && (temperature < 0.0 or temperature > 2.0),
          do: [{:temperature, "must be between 0.0 and 2.0"} | errors],
          else: errors

      # Validate max_tokens
      errors =
        if max_tokens && (max_tokens <= 0 or max_tokens > 4096),
          do: [{:max_tokens, "must be between 1 and 4096"} | errors],
          else: errors

      # Validate system_prompt
      errors =
        if system_prompt && String.length(system_prompt) < 1,
          do: [{:system_prompt, "must not be empty"} | errors],
          else: errors

      if errors != [],
        do: add_error(changeset, :config, "invalid config", errors),
        else: changeset
    else
      changeset
    end
  end
end
