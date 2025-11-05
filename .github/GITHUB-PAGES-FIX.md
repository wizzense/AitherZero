# GitHub Pages Build Fix - Jekyll 4.4 Support

## Problem

The GitHub Pages build was failing with the error:
```
The github-pages gem can't satisfy your Gemfile's dependencies.
```

**Root Cause**: The repository's `Gemfile` specifies `jekyll ~> 4.4` directly, but the `actions/jekyll-build-pages@v1` GitHub Action uses the `github-pages` gem, which has strict version constraints that don't support Jekyll 4.4.

## Solution

Replaced the workflow to build Jekyll using custom GitHub Actions steps following the official Jekyll documentation for continuous integration:
https://jekyllrb.com/docs/continuous-integration/github-actions/

### Changes Made

**File**: `.github/workflows/jekyll-gh-pages.yml`

1. **Removed**: `actions/jekyll-build-pages@v1` action
   - This action internally uses the `github-pages` gem with its version constraints

2. **Added**: Custom Ruby and Jekyll setup
   ```yaml
   - name: Setup Ruby
     uses: ruby/setup-ruby@v1
     with:
       ruby-version: '3.1'
       bundler-cache: true
   ```

3. **Changed**: Build step to use direct Jekyll command
   ```yaml
   - name: Build with Jekyll
     run: bundle exec jekyll build --source ./ --destination ./_site
     env:
       JEKYLL_ENV: production
   ```

4. **Added**: `Gemfile` to workflow triggers
   - Ensures workflow runs when Jekyll dependencies change

5. **Updated**: Workflow name for accuracy
   - Changed from "Deploy Jekyll with GitHub Pages dependencies preinstalled"
   - To "Deploy Jekyll to GitHub Pages"

## Benefits

1. **Flexibility**: Can use any Jekyll version specified in Gemfile
2. **Standard approach**: Follows official Jekyll documentation
3. **Better caching**: `ruby/setup-ruby@v1` has excellent bundler caching
4. **No gem conflicts**: Direct dependency resolution via Bundler
5. **Future-proof**: Not locked to github-pages gem version constraints

## Testing

The workflow will automatically run when:
- Changes are pushed to `main` or `dev` branches
- Changes affect: `reports/`, `docs/`, `index.md`, `_config.yml`, `Gemfile`, or MCP server docs
- Manually triggered via workflow_dispatch

## Verification Steps

After deployment, verify:
1. Build completes successfully in GitHub Actions
2. Site deploys to GitHub Pages
3. All pages render correctly (reports, docs, MCP server docs)
4. No gem dependency errors in build logs

## References

- Jekyll CI/CD Documentation: https://jekyllrb.com/docs/continuous-integration/github-actions/
- ruby/setup-ruby Action: https://github.com/ruby/setup-ruby
- GitHub Pages Configuration: https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site

## Rollback Plan

If issues occur, revert to the previous approach by:
1. Reverting `.github/workflows/jekyll-gh-pages.yml` changes
2. Updating `Gemfile` to use `github-pages` gem instead of direct Jekyll version
3. Remove `kramdown-parser-gfm` (included in github-pages gem)

---

**Fixed**: 2025-11-02  
**Issue**: GitHub Pages gem dependency conflicts  
**Resolution**: Custom Jekyll build with GitHub Actions
