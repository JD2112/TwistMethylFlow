function timeAgo(dateString) {
    const now = new Date();
    const past = new Date(dateString);
    const msPerDay = 24 * 60 * 60 * 1000;
    const days = Math.floor((now - past) / msPerDay);

    if (days === 0) return 'today';
    if (days === 1) return 'yesterday';
    if (days < 30) return `${days} days ago`;
    if (days < 365) return `${Math.floor(days / 30)} months ago`;
    return `${Math.floor(days / 365)} years ago`;
}

async function fetchGitHubStats() {
    const repo = 'JD2112/olinkWrapper';
    const baseUrl = `https://api.github.com/repos/${repo}`;

    try {
        // Fetch repo basic info
        const repoResponse = await fetch(baseUrl);
        if (repoResponse.ok) {
            const data = await repoResponse.json();
            const starsEl = document.getElementById('gh-stars');
            const issuesEl = document.getElementById('gh-issues');
            const updateEl = document.getElementById('gh-last-update');

            if (starsEl) starsEl.textContent = data.stargazers_count;
            if (issuesEl) issuesEl.textContent = data.open_issues_count;
            if (updateEl) updateEl.textContent = timeAgo(data.pushed_at || data.updated_at);
        }

        // Fetch latest release info
        const releaseResponse = await fetch(`${baseUrl}/releases/latest`);
        const releaseEl = document.getElementById('gh-last-release');
        if (releaseEl) {
            if (releaseResponse.ok) {
                const data = await releaseResponse.json();
                releaseEl.textContent = timeAgo(data.published_at || data.created_at);
            } else {
                releaseEl.textContent = 'no release';
            }
        }

        // Fetch contributors
        const contribEl = document.getElementById('gh-contributors');
        if (contribEl) {
            const contribResponse = await fetch(`${baseUrl}/contributors`);
            if (contribResponse.ok) {
                const contributors = await contribResponse.json();
                contribEl.innerHTML = ''; // Clear existing
                contributors.forEach(user => {
                    const link = document.createElement('a');
                    link.href = user.html_url;
                    link.target = '_blank';

                    const img = document.createElement('img');
                    img.src = user.avatar_url;
                    img.className = 'contrib-img';
                    img.title = user.login;
                    img.alt = user.login;

                    link.appendChild(img);
                    contribEl.appendChild(link);
                });
            }
        }
    } catch (error) {
        console.error('Error fetching GitHub stats:', error);
    }
}

// In MkDocs, we might need to handle navigation (instant loading)
document.addEventListener("DOMContentLoaded", fetchGitHubStats);
// For MkDocs Material instant navigation
if (typeof subscribe !== 'undefined') {
    subscribe(({ url }) => fetchGitHubStats());
}
