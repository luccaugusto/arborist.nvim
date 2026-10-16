local worktrees = require("arborist.worktrees")

describe("worktrees", function()
  local sample_trees = {
    { branch = "main", path = "/home/user/repo/main" },
    { branch = "feature-auth", path = "/home/user/repo/feature-auth" },
    { branch = "refs/heads/fix-bug", path = "/home/user/repo/fix-bug" },
    { branch = nil, path = "/home/user/repo/detached" },
    { branch = "deep/nested/branch", path = "/home/user/repo/deep-nested" },
  }

  describe("match_worktree", function()
    it("matches by exact branch name", function()
      assert.equals("/home/user/repo/main", worktrees.match_worktree(sample_trees, "main"))
    end)

    it("matches by exact branch name for feature branch", function()
      assert.equals("/home/user/repo/feature-auth", worktrees.match_worktree(sample_trees, "feature-auth"))
    end)

    it("matches by directory name when branch differs", function()
      -- branch is "refs/heads/fix-bug" but dirname is "fix-bug"
      assert.equals("/home/user/repo/fix-bug", worktrees.match_worktree(sample_trees, "fix-bug"))
    end)

    it("matches by suffix for refs/heads/ prefix", function()
      -- "fix-bug" matches "refs/heads/fix-bug" via suffix
      local trees = {
        { branch = "refs/heads/my-feature", path = "/repo/my-feature" },
      }
      assert.equals("/repo/my-feature", worktrees.match_worktree(trees, "my-feature"))
    end)

    it("returns nil when no match", function()
      assert.is_nil(worktrees.match_worktree(sample_trees, "nonexistent"))
    end)

    it("returns nil for empty trees", function()
      assert.is_nil(worktrees.match_worktree({}, "main"))
    end)

    it("skips entries without path", function()
      local trees = {
        { branch = "main" }, -- no path
        { branch = "main", path = "/repo/main" },
      }
      assert.equals("/repo/main", worktrees.match_worktree(trees, "main"))
    end)

    it("skips entries with nil branch for exact match but matches dirname", function()
      assert.equals("/home/user/repo/detached", worktrees.match_worktree(sample_trees, "detached"))
    end)

    it("handles branch with special regex chars", function()
      local trees = {
        { branch = "fix/issue-123", path = "/repo/fix-issue-123" },
      }
      assert.equals("/repo/fix-issue-123", worktrees.match_worktree(trees, "fix/issue-123"))
    end)

    it("does not false-match partial dirname", function()
      local trees = {
        { branch = "feature", path = "/repo/feature-auth" },
      }
      -- "auth" should not match dirname "feature-auth"
      assert.is_nil(worktrees.match_worktree(trees, "auth"))
    end)

    it("does not false-match partial suffix", function()
      local trees = {
        { branch = "refs/heads/my-feature", path = "/repo/my-feature" },
      }
      -- "feature" should not match "refs/heads/my-feature" via suffix (needs /feature$)
      assert.is_nil(worktrees.match_worktree(trees, "feature"))
    end)

    it("prefers exact branch match over dirname", function()
      local trees = {
        { branch = "other", path = "/repo/main" }, -- dirname "main"
        { branch = "main", path = "/repo/main-worktree" },
      }
      -- Should match first by exact branch, so "main" matches the second entry
      assert.equals("/repo/main-worktree", worktrees.match_worktree(trees, "main"))
    end)
  end)

  describe("normalize_trees", function()
    it("passes the legacy flat array through unchanged", function()
      assert.same(sample_trees, worktrees.normalize_trees(sample_trees))
    end)

    it("flattens schema 2 items", function()
      local decoded = {
        schema = 2,
        items = {
          { branch = "main", worktree = { path = "/repo/main", main = true } },
          { branch = "feature-auth", worktree = { path = "/repo/feature-auth" } },
        },
      }
      assert.same({
        { branch = "main", path = "/repo/main" },
        { branch = "feature-auth", path = "/repo/feature-auth" },
      }, worktrees.normalize_trees(decoded))
    end)

    it("keeps schema 2 branches without a worktree as path-less entries", function()
      local decoded = { schema = 2, items = { { branch = "remote-only" } } }
      assert.same({ { branch = "remote-only" } }, worktrees.normalize_trees(decoded))
    end)

    it("returns an empty list for non-table input", function()
      assert.same({}, worktrees.normalize_trees(vim.NIL))
    end)

    it("resolves a schema 2 path end to end with match_worktree", function()
      local decoded = { items = { { branch = "fix/issue-123", worktree = { path = "/repo/fix-issue-123" } } } }
      assert.equals("/repo/fix-issue-123", worktrees.match_worktree(worktrees.normalize_trees(decoded), "fix/issue-123"))
    end)
  end)
end)
