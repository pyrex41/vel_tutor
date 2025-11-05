# Development data seeding for local development
# Run with: mix run priv/repo/seeds_dev.exs

alias ViralEngine.Repo
alias ViralEngine.Accounts.User

# Clean up existing dev users (optional - comment out if you want to preserve data)
# Repo.delete_all(User)

# Create dev user with session token
# Note: This app uses session tokens, not passwords
dev_user_attrs = %{
  email: "dev@example.com",
  name: "Dev User",
  session_token: "dev_session_token_12345"
}

case %User{}
     |> User.changeset(dev_user_attrs)
     |> Repo.insert() do
  {:ok, user} ->
    IO.puts("✅ Created dev user: #{user.email}")
    IO.puts("   Name: #{user.name}")
    IO.puts("   Session Token: #{user.session_token}")
    IO.puts("🎉 Dev data seeded successfully!")
    IO.puts("")
    IO.puts("Next steps:")
    IO.puts("1. Restart your Phoenix server")
    IO.puts("2. Visit http://localhost:4000 to test authentication bypass")

  {:error, changeset} ->
    # Check if user already exists
    case Repo.get_by(User, email: "dev@example.com") do
      nil ->
        IO.puts("❌ Failed to create dev user:")
        IO.inspect(changeset.errors)
        System.halt(1)

      existing_user ->
        IO.puts("✅ Dev user already exists: #{existing_user.email}")
        IO.puts("   Name: #{existing_user.name}")
        IO.puts("   Session Token: #{existing_user.session_token}")
        IO.puts("🎉 Ready to use existing dev user!")
    end
end
