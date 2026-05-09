# ============================================================================
# STUDYBUDDY-WEB — Dockerfile
# ============================================================================
# Next.js 16 (App Router) frontend with Tailwind, shadcn/ui, Prisma.
# Connects to Supabase (external) for auth, database, and storage.
#
# The build context is the StudyBuddy repo's web/ directory.
# ============================================================================

FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && corepack prepare pnpm@latest --activate
# @tiptap/core and @tiptap/suggestion are used directly in source but only
# transitive deps in package.json. pnpm strict mode blocks phantom deps, so
# we add them explicitly. Version is inferred from @tiptap/react.
# --ignore-scripts bypasses pnpm 10/11 build-script blocking.
# --no-frozen-lockfile allows the new deps to be added.
RUN node -e "\
  const p=require('./package.json');\
  const v=p.dependencies['@tiptap/react'].replace(/[\^~]/,'');\
  p.dependencies['@tiptap/core']='^'+v;\
  p.dependencies['@tiptap/suggestion']='^'+v;\
  require('fs').writeFileSync('package.json',JSON.stringify(p,null,2));"
RUN pnpm install --ignore-scripts --no-frozen-lockfile --prefer-offline

# ── Build stage ────────────────────────────────────────────────────────────
FROM node:22-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN mkdir -p public

# Prisma generate (if schema exists)
RUN npx prisma generate 2>/dev/null || true

# Build Next.js (standalone output for minimal image)
ENV NEXT_TELEMETRY_DISABLED=1
RUN npx next build

# ── Production stage ───────────────────────────────────────────────────────
FROM node:22-alpine AS runner
WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy standalone build
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

USER appuser

ENV NODE_ENV=production
ENV PORT=3002
ENV HOSTNAME="0.0.0.0"
EXPOSE 3002

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -qO- http://localhost:3002/ || exit 1

CMD ["node", "server.js"]
