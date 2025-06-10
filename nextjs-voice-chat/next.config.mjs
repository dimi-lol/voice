/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  experimental: {
    // Remove this if you're not using server components
  },
  // Disable source maps in production for smaller build size
  productionBrowserSourceMaps: false,
  // Optional: Disable ESLint during builds
  eslint: {
    ignoreDuringBuilds: true,
  },
  // Optional: Disable TypeScript errors during builds
  typescript: {
    ignoreBuildErrors: true,
  },
}

export default nextConfig 