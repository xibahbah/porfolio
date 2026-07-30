(function initializePortfolio() {
  const scriptURL = new URL(document.currentScript.src);
  const appRoot = new URL('./', scriptURL);

  const navItems = [
    { path: 'index.html', title: 'Main', className: 'nav-brand' },
    { path: 'projects/index.html', title: 'Projects' },
    { path: 'contact/index.html', title: 'Contact' },
    { path: 'resume/index.html', title: 'Resume', className: 'nav-cta' },
  ];

  const nav = document.createElement('nav');
  nav.className = 'site-nav';
  nav.setAttribute('aria-label', 'Primary');
  document.body.prepend(nav);

  for (const item of navItems) {
    const link = document.createElement('a');
    link.href = new URL(item.path, appRoot).href;
    link.textContent = item.title;

    if (item.className) {
      link.className = item.className;
    }

    const currentURL = new URL(location.href);
    const linkURL = new URL(link.href);
    const currentPath = currentURL.pathname.replace(/\/$/, '/index.html');
    if (
      linkURL.protocol === currentURL.protocol &&
      linkURL.host === currentURL.host &&
      linkURL.pathname === currentPath
    ) {
      link.classList.add('current');
      link.setAttribute('aria-current', 'page');
    }

    nav.append(link);
  }

  function renderProjects(projects, containerElement, headingLevel = 'h2') {
    if (!containerElement || !Array.isArray(projects)) {
      return;
    }

    containerElement.replaceChildren();

    for (const project of projects) {
      const article = document.createElement('article');
      const heading = document.createElement(headingLevel);
      const image = document.createElement('img');
      const metadata = document.createElement('div');
      const description = document.createElement('p');
      const year = document.createElement('p');

      if (project.url) {
        const titleLink = document.createElement('a');
        titleLink.href = project.url;
        titleLink.target = '_blank';
        titleLink.rel = 'noopener noreferrer';
        titleLink.textContent = project.title;
        heading.append(titleLink);
      } else {
        heading.textContent = project.title;
      }

      image.src = new URL(project.image, appRoot).href;
      image.alt = project.title;
      image.loading = 'lazy';
      image.decoding = 'async';

      metadata.className = 'project-meta';
      description.textContent = project.description;
      year.className = 'project-year';
      year.textContent = project.year;
      metadata.append(description, year);

      if (project.url) {
        const projectLink = document.createElement('a');
        projectLink.className = 'project-link';
        projectLink.href = project.url;
        projectLink.target = '_blank';
        projectLink.rel = 'noopener noreferrer';
        projectLink.textContent = 'Open project';
        metadata.append(projectLink);
      }

      article.append(heading, image, metadata);
      containerElement.append(article);
    }
  }

  const form = document.querySelector('form');
  form?.addEventListener('submit', (event) => {
    event.preventDefault();
    const destination = new URL(form.action);
    const data = new FormData(form);

    for (const [name, value] of data) {
      destination.searchParams.set(name, value);
    }

    location.href = destination.href;
  });

  window.Portfolio = Object.freeze({
    appRoot,
    renderProjects,
  });
})();
