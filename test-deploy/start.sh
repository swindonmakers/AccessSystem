#!/bin/bash
set -e

# Ensure we're in the right directory
cd "$(dirname "$0")"

# Check for required tools
if ! command -v docker &> /dev/null; then
    echo "❌ Error: 'docker' is not installed or not in PATH."
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "❌ Error: 'docker compose' is not available."
    echo "   Ensure you have a recent version of Docker Desktop installed."
    exit 1
fi

echo "🚀 Starting Production Container Test Environment..."

# Create config if it doesn't exist
if [ ! -f config/accesssystem_api_local.conf ]; then
    echo "⚙️  Creating default test configuration..."
    mkdir -p config
    cat > config/accesssystem_api_local.conf <<EOL
# Local config for docker-compose testing with PostgreSQL
<Model::AccessDB>
  <connect_info>
    dsn dbi:Pg:dbname=accesssystem;host=db
    user access
    password accesstest
  </connect_info>
</Model::AccessDB>

# Dummy reCAPTCHA keys (Google test keys)
<HTML::FormHandlerX::Field::noCAPTCHA>
  site_key 6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI
  secret_key 6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe
</HTML::FormHandlerX::Field::noCAPTCHA>

# Dummy OneAll settings
<OneAll>
  subdomain test
  domain test.api.oneall.com
  public_key test-public-key
  private_key test-private-key
</OneAll>

# Cookie settings
<authen_cookie>
  name access_system_test
  mac_secret docker-test-cookie-secret
</authen_cookie>

<Controller::Root>
  namespace accesssystem
</Controller::Root>

# Dummy Sendinblue/Brevo settings
<Sendinblue>
  api-key dummy-test-api-key
</Sendinblue>

base_url http://localhost:3000/accesssystem/
EOL
fi

# Build (using parent context)
echo "📦 Building production image..."
docker build --target production -t accesssystem:latest ..

# Start containers
echo "🔄 Starting containers..."
docker compose up -d

# Wait for DB
# Wait for DB to be healthy
echo "⏳ Waiting for Database to be ready..."
RETRIES=30
until docker compose exec -T db pg_isready -U access -d accesssystem > /dev/null 2>&1; do
  ((RETRIES--))
  if [ $RETRIES -le 0 ]; then
    echo "❌ Database failed to start in time."
    exit 1
  fi
  echo "zzz... waiting for database ($RETRIES retries left)"
  sleep 2
done
echo "✅ Database is up!"

# Deploy Schema
echo "📜 Deploying Schema (v18.0 PostgreSQL)..."
docker compose exec -T db psql -U access -d accesssystem < ../sql/AccessSystem-Schema-18.0-PostgreSQL.sql

# Seed Data
echo "🌱 Seeding Data..."
docker compose exec -T db psql -U access -d accesssystem < seed_data.sql

echo "✅ Environment Ready!"
echo "➡️  Login: http://localhost:3000/login"
echo "➡️  Register: http://localhost:3000/register"
echo ""
echo "To stop: docker compose down -v"
