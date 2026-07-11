# Stage 1: Build the NestJS application
FROM node:22-alpine AS builder

WORKDIR /usr/src/app

# Copy dependency manifests
COPY package*.json ./
COPY prisma ./prisma/

# Install all dependencies (including devDependencies)
RUN npm ci

# Copy codebase source files
COPY . .

# Generate Prisma Client and build the application
RUN npx prisma generate
RUN npm run build

# Stage 2: Production image runner
FROM node:22-alpine AS runner

WORKDIR /usr/src/app

ENV NODE_ENV=production

# Copy package manifests
COPY package*.json ./
COPY prisma ./prisma/

# Install production dependencies only
RUN npm ci --only=production

# Copy built application and generated prisma client from builder stage
COPY --from=builder /usr/src/app/dist ./dist
COPY --from=builder /usr/src/app/node_modules/@prisma/client ./node_modules/@prisma/client

# Expose port (default NestJS port 3000)
EXPOSE 3000

# Start the application
CMD ["node", "dist/main"]
