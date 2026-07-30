(function initializeProjectsPage() {
  const projects = Array.isArray(window.PORTFOLIO_PROJECTS)
    ? window.PORTFOLIO_PROJECTS
    : [];
  const projectsContainer = document.querySelector('.projects');
  const projectsTitle = document.querySelector('.projects-title');
  const searchInput = document.querySelector('.searchBar');
  const pieChart = document.querySelector('#projects-pie-plot');
  const legend = document.querySelector('.legend');
  const colors = [
    '#4e79a7',
    '#f28e2b',
    '#e15759',
    '#76b7b2',
    '#59a14f',
    '#edc949',
    '#af7aa1',
    '#ff9da7',
    '#9c755f',
    '#bab0ab',
  ];
  const svgNamespace = 'http://www.w3.org/2000/svg';

  let query = '';
  let selectedYear = null;

  if (projectsTitle) {
    projectsTitle.textContent = `${projects.length} Projects`;
  }

  function getSearchFilteredProjects() {
    const normalizedQuery = query.trim().toLocaleLowerCase();

    return projects.filter((project) =>
      Object.values(project)
        .join('\n')
        .toLocaleLowerCase()
        .includes(normalizedQuery),
    );
  }

  function polarPoint(angle, radius = 50) {
    return {
      x: Math.cos(angle) * radius,
      y: Math.sin(angle) * radius,
    };
  }

  function slicePath(startAngle, endAngle) {
    const start = polarPoint(startAngle);
    const end = polarPoint(endAngle);
    const largeArc = endAngle - startAngle > Math.PI ? 1 : 0;

    if (endAngle - startAngle >= Math.PI * 2 - Number.EPSILON) {
      return [
        'M 0 -50',
        'A 50 50 0 1 1 0 50',
        'A 50 50 0 1 1 0 -50',
        'Z',
      ].join(' ');
    }

    return [
      'M 0 0',
      `L ${start.x} ${start.y}`,
      `A 50 50 0 ${largeArc} 1 ${end.x} ${end.y}`,
      'Z',
    ].join(' ');
  }

  function activateYear(year) {
    selectedYear = selectedYear === year ? null : year;
    render();
  }

  function makeInteractive(element, label, year) {
    element.setAttribute('tabindex', '0');
    element.setAttribute('role', 'button');
    element.setAttribute('aria-label', label);
    element.addEventListener('click', () => activateYear(year));
    element.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        activateYear(year);
      }
    });
  }

  function renderPieChart(projectsToVisualize) {
    pieChart.replaceChildren();
    legend.replaceChildren();

    const counts = new Map();
    for (const project of projectsToVisualize) {
      counts.set(project.year, (counts.get(project.year) ?? 0) + 1);
    }

    const data = [...counts.entries()]
      .sort(([yearA], [yearB]) => yearA.localeCompare(yearB))
      .map(([year, count]) => ({ year, count }));
    const total = data.reduce((sum, item) => sum + item.count, 0);

    if (total === 0) {
      const emptyMessage = document.createElement('li');
      emptyMessage.textContent = 'No projects match this search.';
      legend.append(emptyMessage);
      return;
    }

    let angle = -Math.PI / 2;
    data.forEach((item, index) => {
      const nextAngle = angle + (item.count / total) * Math.PI * 2;
      const path = document.createElementNS(svgNamespace, 'path');
      path.setAttribute('d', slicePath(angle, nextAngle));
      path.setAttribute('fill', colors[index % colors.length]);
      if (item.year === selectedYear) {
        path.classList.add('selected');
      }
      makeInteractive(path, `${item.year}: ${item.count} projects`, item.year);
      pieChart.append(path);
      angle = nextAngle;

      const legendItem = document.createElement('li');
      const swatch = document.createElement('span');
      const count = document.createElement('em');
      legendItem.className = 'legend-item';
      if (item.year === selectedYear) {
        legendItem.classList.add('selected');
      }
      legendItem.style.setProperty('--color', colors[index % colors.length]);
      swatch.className = 'swatch';
      count.textContent = `(${item.count})`;
      legendItem.append(swatch, document.createTextNode(`${item.year} `), count);
      makeInteractive(
        legendItem,
        `Filter to ${item.year} projects`,
        item.year,
      );
      legend.append(legendItem);
    });
  }

  function render() {
    const searchFilteredProjects = getSearchFilteredProjects();
    const availableYears = new Set(
      searchFilteredProjects.map((project) => project.year),
    );

    if (selectedYear && !availableYears.has(selectedYear)) {
      selectedYear = null;
    }

    const visibleProjects = selectedYear
      ? searchFilteredProjects.filter(
          (project) => project.year === selectedYear,
        )
      : searchFilteredProjects;

    window.Portfolio.renderProjects(
      visibleProjects,
      projectsContainer,
      'h2',
    );
    renderPieChart(searchFilteredProjects);
  }

  searchInput.addEventListener('input', (event) => {
    query = event.target.value;
    render();
  });

  render();
})();
