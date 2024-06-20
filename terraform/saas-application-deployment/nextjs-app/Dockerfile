# Dockerfile

# Use the official Node.js 16 image as the base image
FROM node:18.17.0-alpine

# Set the working directory
WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application code
COPY . .

# Build the Next.js application
RUN npm run build

# Expose port 3000
EXPOSE 3000

# Define environment variable for PostgreSQL connection
ENV DATABASE_URL=postgres://saas:h9IDelf2P<5q8+Io811Qph4TM}?{@saas-stg-db.cb2kyu8aixy4.eu-west-2.rds.amazonaws.com:5432/mydatabase

# Start the Next.js application
CMD ["npm", "start"]
