# BMAD Migration Guide: Anthropic → OpenAI/Groq

## Overview

This guide helps you transition your BMAD installation from Anthropic Claude models to OpenAI GPT models with optional Groq integration for faster inference.

## Step 1: API Key Migration

### Remove Anthropic Configuration

1. **Update `.env`**:
```bash
# Remove or comment out
# ANTHROPIC_API_KEY=your_old_key

# Add OpenAI (required)
OPENAI_API_KEY=sk-your_openai_api_key_here

# Add Groq (optional but recommended for speed)
GROQ_API_KEY=gsk-your_groq_api_key_here

# Keep Perplexity for research (optional)
PERPLEXITY_API_KEY=pplx-your_perplexity_key_here
```

2. **Update `.mcp.json`**:
```json
{
  "mcpServers": {
    "task-master-ai": {
      "env": {
        "OPENAI_API_KEY": "your_openai_key_here",
        "GROQ_API_KEY": "your_groq_key_here"
      }
    }
  }
}
```

## Step 2: Model Configuration

### Task Master Models

Run the interactive setup:

```bash
task-master models --setup
```

Or configure directly:

```bash
# Primary model for complex tasks
task-master models --set-main gpt-4o

# Research model (lighter, faster)
task-master models --set-research gpt-4o-mini

# Fallback for speed/cost (Groq)
task-master models --set-fallback groq-llama-3.1-70b-versatile
```

### BMAD Configuration

Update `bmad/core/config.yaml`:

```yaml
openai:
  api_key: $OPENAI_API_KEY
  model: gpt-4o
  base_url: https://api.openai.com/v1

groq:
  api_key: $GROQ_API_KEY
  model: llama-3.1-70b-versatile
  base_url: https://api.groq.com/openai/v1

default_provider: openai
fallback_provider: groq
```

Update `bmad/bmm/config.yaml`:

```yaml
api_provider: openai
primary_model: gpt-4o
research_model: gpt-4o-mini
fallback_model: groq-llama-3.1-70b-versatile
```

## Step 3: Workflow Updates

### Prompt Engineering Differences

**Anthropic → OpenAI Migration:**

1. **System Prompts**: OpenAI uses similar XML-style tags but prefers natural language
   ```yaml
   # Old (Anthropic)
   system: |
     <role>Architect</role>
     You are a system architect...

   # New (OpenAI)
   system: |
     You are Winston, a senior system architect specializing in distributed systems...
   ```

2. **Tool Calling**: OpenAI uses function calling syntax
   ```json
   {
     "type": "function",
     "function": {
       "name": "get_weather",
       "parameters": { ... }
     }
   }
   ```

3. **Response Format**: OpenAI returns structured JSON more reliably
   ```python
   # OpenAI response parsing
   response = client.chat.completions.create(
     model="gpt-4o",
     messages=messages,
     response_format={"type": "json_object"}
   )
   ```

### Agent Behavior Changes

**Expected Differences:**

- **Token Efficiency**: GPT-4o is more concise than Claude 3.5
- **Code Generation**: OpenAI excels at code completion and refactoring
- **Reasoning**: Similar capabilities, but OpenAI may need more explicit instructions
- **Speed**: Groq provides 5-10x faster inference than OpenAI API

**Prompt Adjustments:**

1. **Be More Explicit**: OpenAI benefits from clearer task boundaries
2. **Use JSON Mode**: For structured outputs, specify `response_format`
3. **Chain of Thought**: Explicitly ask for step-by-step reasoning
4. **Tool Use**: Use function calling for complex operations

## Step 4: Performance Tuning

### Groq Integration

Groq provides ultra-fast inference with open models:

**Available Models:**
- `llama-3.1-70b-versatile`: General purpose, high quality
- `llama-3.1-8b-instant`: Fast, lightweight
- `mixtral-8x7b-32768`: Good balance of speed and capability

**Configuration:**
```bash
# Set Groq as fallback for speed
task-master models --set-fallback groq-llama-3.1-70b-versatile

# Use Groq for research tasks (fast web search)
task-master models --set-research groq-mixtral-8x7b-32768
```

### Cost Optimization

**Token Usage Comparison:**
- GPT-4o: $5/1M input, $15/1M output
- GPT-4o-mini: $0.15/1M input, $0.60/1M output  
- Groq Llama 3.1 70B: $0.59/1M input, $0.79/1M output
- Groq Llama 3.1 8B: $0.05/1M input, $0.08/1M output

**Optimization Strategy:**
1. Use GPT-4o for architecture and planning
2. Use GPT-4o-mini for task expansion and updates
3. Use Groq for code generation and validation
4. Use Perplexity for research and documentation

## Step 5: Testing the Migration

### Validation Commands

```bash
# Test model connectivity
task-master models

# Test task generation
task-master add-task --prompt="Create a simple API endpoint" --research

# Test workflow execution
task-master next

# Validate BMAD agents
cd bmad && ./test-agents.sh
```

### Performance Benchmarks

Create a benchmark script:

```bash
#!/bin/bash
# benchmark.sh

echo "Benchmarking AI providers..."

# Test response time
time task-master add-task --prompt="Explain REST API design" > /dev/null

# Test token usage
task-master analyze-complexity --research --ids="1,2,3" > complexity.json

# Test code generation
task-master expand --id=1 --num=5 > /dev/null

echo "Migration complete! Monitor performance and adjust models as needed."
```

## Step 6: Troubleshooting

### Common Issues

**1. Rate Limits**
```bash
# OpenAI rate limits are stricter than Anthropic
# Monitor usage in OpenAI dashboard
# Use Groq for high-volume operations
```

**2. Model Differences**
- GPT-4o may generate more verbose responses
- Use `max_tokens` parameter to control length
- Groq models may need temperature adjustment (0.1-0.3 recommended)

**3. Tool Calling**
```python
# OpenAI function calling syntax
response = client.chat.completions.create(
  model="gpt-4o",
  messages=messages,
  tools=tools,
  tool_choice="auto",
  temperature=0.1
)
```

### Fallback Strategy

If OpenAI experiences issues:

1. **Immediate Fallback**: Groq Llama 3.1 70B
2. **Cost Fallback**: GPT-4o-mini  
3. **Emergency**: Local Ollama models

Configuration in `bmad/core/config.yaml`:
```yaml
providers:
  primary: openai/gpt-4o
  fallback_1: groq/llama-3.1-70b-versatile
  fallback_2: openai/gpt-4o-mini
  emergency: ollama/codellama
```

## Step 7: Monitoring & Optimization

### Usage Tracking

Add to your `.env`:
```bash
# Enable detailed logging
BMAD_LOG_LEVEL=debug
OPENAI_LOG=info
GROQ_LOG=info
```

### Performance Metrics

Monitor these key metrics:

1. **Response Time**: Target < 3s for Groq, < 10s for OpenAI
2. **Token Efficiency**: Aim for < 2k tokens per task operation
3. **Success Rate**: > 95% first-pass completion
4. **Cost per Task**: Track and optimize model selection

### Model Selection Guidelines

| Task Type | Recommended Model | Provider | Reason |
|-----------|------------------|----------|---------|
| Architecture Design | GPT-4o | OpenAI | Complex reasoning |
| Code Generation | Groq Llama 3.1 70B | Groq | Speed + quality |
| Task Planning | GPT-4o-mini | OpenAI | Cost-effective |
| Research | Perplexity Sonar | Perplexity | Web access |
| Validation | Groq Mixtral | Groq | Fast review |
| Documentation | GPT-4o-mini | OpenAI | Concise output |

## Next Steps

1. **Test thoroughly** with your existing workflows
2. **Monitor costs** during the first week
3. **Tune prompts** based on OpenAI response patterns
4. **Consider hybrid approach** - use Groq for speed-critical paths
5. **Document findings** in your team knowledge base

The migration should improve your development speed while maintaining (or improving) code quality. Groq's inference speed will be particularly noticeable for iterative development tasks.

For questions, refer to the [BMAD Discord community](https://discord.gg/bmad) or file an issue on GitHub.