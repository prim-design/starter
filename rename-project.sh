#!/bin/bash

# Script to rename the TT template to your project name
# Usage: ./rename-project.sh my-project

set -e

if [ -z "$1" ]; then
  echo "Error: Please provide a project name"
  echo "Usage: ./rename-project.sh my-project"
  echo ""
  echo "Example: ./rename-project.sh teachtab"
  echo "  This will create: teachtab-client, teachtab-server, teachtab-shared"
  exit 1
fi

PROJECT_NAME="$1"
CLIENT_NAME="${PROJECT_NAME}-client"
SERVER_NAME="${PROJECT_NAME}-server"
SHARED_NAME="${PROJECT_NAME}-shared"
# Convert to uppercase for binding name (e.g., MY_PROJECT_SERVER)
BINDING_NAME="$(echo "$PROJECT_NAME" | tr '[:lower:]' '[:upper:]')_SERVER"

echo "Renaming TT template to: $PROJECT_NAME"
echo ""
echo "  Client: tt-client -> $CLIENT_NAME"
echo "  Server: tt-server -> $SERVER_NAME"
echo "  Shared: tt-shared -> $SHARED_NAME"
echo "  Binding: TT_SERVER -> $BINDING_NAME"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 1
fi

echo ""
echo "Step 1: Renaming directories..."
mv tt-client "$CLIENT_NAME"
mv tt-server "$SERVER_NAME"
mv tt-shared "$SHARED_NAME"
echo "Done: Directories renamed"

echo ""
echo "Step 2: Updating pnpm-workspace.yaml..."
sed -i.bak "s/tt-server/$SERVER_NAME/g" pnpm-workspace.yaml
sed -i.bak "s/tt-client/$CLIENT_NAME/g" pnpm-workspace.yaml
sed -i.bak "s/tt-shared/$SHARED_NAME/g" pnpm-workspace.yaml
rm pnpm-workspace.yaml.bak
echo "Done: pnpm-workspace.yaml updated"

echo ""
echo "Step 3: Updating package.json files..."

# Update client package.json
sed -i.bak "s/\"name\": \"tt-client\"/\"name\": \"$CLIENT_NAME\"/" "$CLIENT_NAME/package.json"
sed -i.bak "s/tt-shared/$SHARED_NAME/g" "$CLIENT_NAME/package.json"
rm "$CLIENT_NAME/package.json.bak"

# Update server package.json
sed -i.bak "s/\"name\": \"tt-server\"/\"name\": \"$SERVER_NAME\"/" "$SERVER_NAME/package.json"
sed -i.bak "s/tt-shared/$SHARED_NAME/g" "$SERVER_NAME/package.json"
sed -i.bak "s/tt-database/${PROJECT_NAME}-database/g" "$SERVER_NAME/package.json"
rm "$SERVER_NAME/package.json.bak"

# Update shared package.json
sed -i.bak "s/\"name\": \"tt-shared\"/\"name\": \"$SHARED_NAME\"/" "$SHARED_NAME/package.json"
rm "$SHARED_NAME/package.json.bak"

echo "Done: package.json files updated"

echo ""
echo "Step 4: Updating wrangler.jsonc files..."

# Update server wrangler.jsonc
sed -i.bak "s/\"name\": \"tt-server\"/\"name\": \"$SERVER_NAME\"/" "$SERVER_NAME/wrangler.jsonc"
sed -i.bak "s/database_name\": \"tt-database\"/database_name\": \"${PROJECT_NAME}-database\"/" "$SERVER_NAME/wrangler.jsonc"
rm "$SERVER_NAME/wrangler.jsonc.bak"

# Update client wrangler.jsonc
sed -i.bak "s/\"name\": \"tt-client\"/\"name\": \"$CLIENT_NAME\"/" "$CLIENT_NAME/wrangler.jsonc"
sed -i.bak "s/\"service\": \"tt-server\"/\"service\": \"$SERVER_NAME\"/" "$CLIENT_NAME/wrangler.jsonc"
sed -i.bak "s/\"binding\": \"TT_SERVER\"/\"binding\": \"$BINDING_NAME\"/" "$CLIENT_NAME/wrangler.jsonc"
sed -i.bak "s/tt-server/$SERVER_NAME/g" "$CLIENT_NAME/wrangler.jsonc"
rm "$CLIENT_NAME/wrangler.jsonc.bak"

echo "Done: wrangler.jsonc files updated"

echo ""
echo "Step 5: Updating source code imports..."

# Update client worker.ts binding name
sed -i.bak "s/TT_SERVER/$BINDING_NAME/g" "$CLIENT_NAME/src/worker.ts"
sed -i.bak "s/tt-server/$SERVER_NAME/g" "$CLIENT_NAME/src/worker.ts"
rm "$CLIENT_NAME/src/worker.ts.bak"

# Update all source files that import from tt-shared
find "$CLIENT_NAME/src" -name "*.ts" -o -name "*.tsx" | while read file; do
  if grep -q "tt-shared" "$file" 2>/dev/null; then
    sed -i.bak "s/tt-shared/$SHARED_NAME/g" "$file"
    rm "${file}.bak"
  fi
done

# Update client index.html title
if [ -f "$CLIENT_NAME/index.html" ]; then
  sed -i.bak "s/tt-client/$CLIENT_NAME/g" "$CLIENT_NAME/index.html"
  rm "$CLIENT_NAME/index.html.bak"
fi

# Update client .env.production URLs
if [ -f "$CLIENT_NAME/.env.production" ]; then
  sed -i.bak "s/tt-server/$SERVER_NAME/g" "$CLIENT_NAME/.env.production"
  sed -i.bak "s/tt-client/$CLIENT_NAME/g" "$CLIENT_NAME/.env.production"
  rm "$CLIENT_NAME/.env.production.bak"
fi

find "$SERVER_NAME/src" -name "*.ts" | while read file; do
  if grep -q "tt-shared" "$file" 2>/dev/null; then
    sed -i.bak "s/tt-shared/$SHARED_NAME/g" "$file"
    rm "${file}.bak"
  fi
done

echo "Done: Source imports updated"

echo ""
echo "Step 6: Updating documentation files..."

# Update README.md
sed -i.bak "s/tt-client/$CLIENT_NAME/g" README.md
sed -i.bak "s/tt-server/$SERVER_NAME/g" README.md
sed -i.bak "s/tt-shared/$SHARED_NAME/g" README.md
rm README.md.bak

# Update CLAUDE.md
sed -i.bak "s/tt-client/$CLIENT_NAME/g" CLAUDE.md
sed -i.bak "s/tt-server/$SERVER_NAME/g" CLAUDE.md
sed -i.bak "s/tt-shared/$SHARED_NAME/g" CLAUDE.md
sed -i.bak "s/TT_SERVER/$BINDING_NAME/g" CLAUDE.md
CAPITALIZED_NAME="$(echo "${PROJECT_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${PROJECT_NAME:1}"
sed -i.bak "s/TT Template/${CAPITALIZED_NAME} Template/g" CLAUDE.md
rm CLAUDE.md.bak

# Update AGENTS.md if it exists
if [ -f "AGENTS.md" ]; then
  sed -i.bak "s/tt-client/$CLIENT_NAME/g" AGENTS.md
  sed -i.bak "s/tt-server/$SERVER_NAME/g" AGENTS.md
  sed -i.bak "s/tt-shared/$SHARED_NAME/g" AGENTS.md
  sed -i.bak "s/TT_SERVER/$BINDING_NAME/g" AGENTS.md
  rm AGENTS.md.bak
fi

# Update STRIPE_SETUP.md if it exists
if [ -f "STRIPE_SETUP.md" ]; then
  sed -i.bak "s/tt-client/$CLIENT_NAME/g" STRIPE_SETUP.md
  sed -i.bak "s/tt-server/$SERVER_NAME/g" STRIPE_SETUP.md
  sed -i.bak "s/tt-database/${PROJECT_NAME}-database/g" STRIPE_SETUP.md
  rm STRIPE_SETUP.md.bak
fi

# Update AUTH_SETUP.md if it exists
if [ -f "AUTH_SETUP.md" ]; then
  sed -i.bak "s/tt-client/$CLIENT_NAME/g" AUTH_SETUP.md
  sed -i.bak "s/tt-server/$SERVER_NAME/g" AUTH_SETUP.md
  rm AUTH_SETUP.md.bak
fi

# Update shared README.md if it exists
if [ -f "$SHARED_NAME/README.md" ]; then
  sed -i.bak "s/tt-shared/$SHARED_NAME/g" "$SHARED_NAME/README.md"
  sed -i.bak "s/tt-server/$SERVER_NAME/g" "$SHARED_NAME/README.md"
  rm "$SHARED_NAME/README.md.bak"
fi

echo "Done: Documentation updated"

echo ""
echo "Step 7: Updating GitHub workflows..."

if [ -d ".github/workflows" ]; then
  sed -i.bak "s/tt-server/$SERVER_NAME/g" .github/workflows/deploy-server.yml
  sed -i.bak "s/tt-shared/$SHARED_NAME/g" .github/workflows/deploy-server.yml
  sed -i.bak "s/tt-client/$CLIENT_NAME/g" .github/workflows/deploy-client.yml
  sed -i.bak "s/tt-shared/$SHARED_NAME/g" .github/workflows/deploy-client.yml
  rm .github/workflows/*.bak 2>/dev/null || true
  echo "Done: GitHub workflows updated"
else
  echo "Skipped: No .github/workflows directory found"
fi

echo ""
echo "========================================"
echo "Project renamed to: $PROJECT_NAME"
echo "========================================"
echo ""
echo "Next steps:"
echo ""
echo "  1. Create D1 database:"
echo "     cd $SERVER_NAME && pnpm exec wrangler d1 create ${PROJECT_NAME}-database"
echo ""
echo "  2. Update database_id in $SERVER_NAME/wrangler.jsonc with the output from step 1"
echo ""
echo "  3. Reinstall dependencies:"
echo "     pnpm install"
echo ""
echo "  4. Generate Prisma client:"
echo "     pnpm --filter $SERVER_NAME run db:generate"
echo ""
echo "  5. Run database migrations:"
echo "     pnpm --filter $SERVER_NAME run db:migrate:local"
echo ""
echo "  6. Create .dev.vars file:"
echo "     See README.md for required environment variables"
echo ""
echo "  7. Start development:"
echo "     Terminal 1: pnpm --filter $SERVER_NAME dev"
echo "     Terminal 2: cd $CLIENT_NAME && VITE_API_BASE=http://localhost:8787 pnpm dev"
echo ""
