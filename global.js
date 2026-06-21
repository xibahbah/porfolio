export function $$(selector, context = document) {
  return Array.from(context.querySelectorAll(selector));
}

const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1', '::1', '']);
const BASE_PATH = LOCAL_HOSTS.has(location.hostname)
  ? '/'
  : location.pathname.startsWith('/porfolio/')
    ? '/porfolio/'
    : '/';

const navItems = [
  { url: BASE_PATH, title: 'Main', className: 'nav-brand' },
  { url: `${BASE_PATH}resume/`, title: 'Resume', className: 'nav-cta' },
];

const nav = document.createElement('nav');
nav.className = 'site-nav';
nav.setAttribute('aria-label', 'Primary');
document.body.prepend(nav);

for (const item of navItems) {
  const link = document.createElement('a');
  link.href = item.url;
  link.textContent = item.title;

  if (item.className) {
    link.className = item.className;
  }

  const isInternal = link.host === location.host;
  const normalizedPath = location.pathname.endsWith('/')
    ? location.pathname
    : `${location.pathname}/`;

  if (isInternal && link.pathname === normalizedPath && !link.hash) {
    link.classList.add('current');
  }

  nav.append(link);
}

export async function fetchJSON(url) {
  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch: ${response.statusText}`);
    }
    return await response.json();
  } catch (error) {
    console.error('Error fetching or parsing JSON data:', error);
    return null;
  }
}

export function renderProjects(projects, containerElement, headingLevel = 'h2') {
  if (!containerElement || !Array.isArray(projects)) {
    return;
  }

  containerElement.innerHTML = '';

  for (const project of projects) {
    const article = document.createElement('article');
    const title = project.url
      ? `<a href="${project.url}" target="_blank" rel="noopener noreferrer">${project.title}</a>`
      : project.title;
    const link = project.url
      ? `<a class="project-link" href="${project.url}" target="_blank" rel="noopener noreferrer">Open project</a>`
      : '';

    article.innerHTML = `
      <${headingLevel}>${title}</${headingLevel}>
      <img src="${BASE_PATH}${project.image}" alt="${project.title}">
      <div class="project-meta">
        <p>${project.description}</p>
        <p class="project-year">${project.year}</p>
        ${link}
      </div>
    `;
    containerElement.append(article);
  }
}

export async function fetchGitHubData(username) {
  return fetchJSON(`https://api.github.com/users/${username}`);
}

const form = document.querySelector('form');
form?.addEventListener('submit', (event) => {
  event.preventDefault();
  const data = new FormData(form);
  const params = [];

  for (const [name, value] of data) {
    params.push(`${name}=${encodeURIComponent(value)}`);
  }

  location.href = `${form.action}?${params.join('&')}`;
});
