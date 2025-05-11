const container = document.getElementById('project-container');
const username = 'ScoRoss';
const highlightDays = 7;

function isRecent(dateStr) {
  const updated = new Date(dateStr);
  const now = new Date();
  const diffTime = Math.abs(now - updated);
  return (diffTime / (1000 * 60 * 60 * 24)) <= highlightDays;
}

fetch(`https://api.github.com/users/${username}/repos`)
  .then(res => res.json())
  .then(repos => {
    // Prioritize the Corsair website repo
    const pinned = repos.find(r => r.name === 'Corsair-development');
    const sorted = pinned ? [pinned, ...repos.filter(r => r.name !== 'Corsair-development')] : repos;

    sorted.forEach(repo => {
      const card = document.createElement('div');
      card.className = 'project-card';

      card.innerHTML = `
        <h3>${repo.name}</h3>
        <p>${repo.description || 'No description available.'}</p>
        <a href="${repo.html_url}" target="_blank">View Repo</a>
        ${isRecent(repo.updated_at) ? '<span class="badge new">New Commit!</span>' : ''}
      `;

      container.appendChild(card);
    });
  })
  .catch(err => {
    container.innerHTML = '<p>Failed to load projects.</p>';
    console.error(err);
  });
