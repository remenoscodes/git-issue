class GitIssue < Formula
  desc "Distributed issue tracking system built on Git"
  homepage "https://github.com/remenoscodes/git-issue"
  url "https://github.com/remenoscodes/git-issue/releases/download/v1.0.1/git-issue-v1.0.1.tar.gz"
  sha256 "0539533d62a3049d8bb87d1db91d80b8da09d29026294a6e04f4f50f1fd3b437"  # Update this after creating v1.0.1 release
  license "GPL-2.0-only"
  version "1.0.1"

  depends_on "git"

  def install
    # Install binaries
    bin.install Dir["bin/*"]

    # Install man pages if present
    man1.install Dir["doc/*.1"] if Dir.exist?("doc")

    # Install documentation
    doc.install "README.md", "LICENSE", "ISSUE-FORMAT.md"
  end

  test do
    system "#{bin}/git-issue", "version"
    assert_match "1.0.1", shell_output("#{bin}/git-issue version")
  end
end
