# Test data seeding for E2E tests
# Run with: MIX_ENV=test mix run priv/repo/seeds_test.exs

alias ViralEngine.Repo
alias ViralEngine.Accounts.User

# Clean up existing test users
Repo.delete_all(User)

# Create test user with session token
# Note: This app uses session tokens, not passwords
test_user_attrs = %{
  email: "test@example.com",
  name: "Test User",
  session_token: "test_session_token_12345"
}

case %User{}
     |> User.changeset(test_user_attrs)
     |> Repo.insert() do
  {:ok, user} ->
    IO.puts("✅ Created test user: #{user.email}")
    IO.puts("   Name: #{user.name}")
    IO.puts("   Session Token: #{user.session_token}")
    IO.puts("🎉 Test data seeded successfully!")

  {:error, changeset} ->
    IO.puts("❌ Failed to create test user:")
    IO.inspect(changeset.errors)
    System.halt(1)
end
