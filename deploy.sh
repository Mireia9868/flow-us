#!/bin/bash
# 部署前端到 Cloudflare Pages
#
# 前置：已执行 npx wrangler login（或设置 CLOUDFLARE_API_TOKEN）
# 用法：./deploy.sh（生产）或 FLOW_US_PAGES_BRANCH=growth/first-run-metrics ./deploy.sh（预览）
#
# 说明：Pages 会对 .html 做去扩展名跳转，所以部署产物统一叫 index.html，
#       保证访问域名根路径直接命中工作台，不产生重定向。

set -e
cd "$(dirname "$0")"

WRANGLER=${WRANGLER:-npx wrangler}

rm -rf dist
mkdir -p dist
cp focus-desk.html dist/index.html
cp _redirects dist/ 2>/dev/null || true
cp _routes.json dist/

branch=${FLOW_US_PAGES_BRANCH:-main}
echo "==> 部署到 Cloudflare Pages (flow-us / $branch)"
CLOUDFLARE_ACCOUNT_ID=${CLOUDFLARE_ACCOUNT_ID:-0df8bb5406f7f6b99a514034e9646886} \
  $WRANGLER pages deploy dist --project-name=flow-us --branch="$branch"
