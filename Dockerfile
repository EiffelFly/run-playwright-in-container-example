# Install dependencies only when needed
FROM --platform=$BUILDPLATFORM node:16-alpine AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
WORKDIR /app

RUN npm install -g pnpm@7.5.0

COPY package.json pnpm-lock.yaml ./

RUN pnpm install --frozen-lockfile

# If using npm with a `package-lock.json` comment out above and use below instead
# COPY package.json package-lock.json ./ 
# RUN npm ci

# Rebuild the source code only when needed
FROM --platform=$BUILDPLATFORM node:16-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules

RUN npm install -g pnpm@7.5.0

# You need to make sure the .env doesn't have senesitive data. Please store sensitive data at .env.local.
# Pay attention about the duplicated env variables, nextjs will always prioritize the .env file. Store the env variables
# at .env.local if they will conflict with the same variables on production, e.g. some variables comes from docker-compose.

COPY . .

# Next.js collects completely anonymous telemetry data about general usage.
# Learn more here: https://nextjs.org/telemetry
# Uncomment the following line in case you want to disable telemetry during the build.
ENV NEXT_TELEMETRY_DISABLED 1

RUN pnpm run build 

# Production image, copy all the files and run next
FROM node:16-alpine
WORKDIR /app

ENV NODE_ENV production
# Uncomment the following line in case you want to disable telemetry during runtime.
# ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# You need to copy next.config.js if you are NOT using the default configuration
COPY --from=builder /app/next.config.js ./
COPY --from=builder /app/package.json ./package.json

# We need to grant nextjs user to have the permission to alter the /public folder to
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

# Automatically leverage output traces to reduce image size 
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

# We need this permission for env.sh to create the __env.js in /public folder
RUN chmod +wx ./public

EXPOSE 3000

ENV PORT 3000

ENTRYPOINT ["node", "server.js"]