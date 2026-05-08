import * as d3 from 'https://cdn.jsdelivr.net/npm/d3@7.9.0/+esm';
import { fetchJSON, renderProjects } from '../global.js';

const projects = await fetchJSON('../lib/projects.json');
const projectsContainer = document.querySelector('.projects');
const projectsTitle = document.querySelector('.projects-title');
const searchInput = document.querySelector('.searchBar');
const pieRadius = 50;
const arcGenerator = d3.arc().innerRadius(0).outerRadius(pieRadius);
const colors = d3.scaleOrdinal(d3.schemeTableau10);

let query = '';
let selectedYear = null;

if (projectsTitle) {
  projectsTitle.textContent = `${projects.length} Projects`;
}

function getSearchFilteredProjects() {
  const normalizedQuery = query.toLowerCase();

  return projects.filter((project) => {
    const values = Object.values(project).join('\n').toLowerCase();
    return values.includes(normalizedQuery);
  });
}

function renderPieChart(projectsToVisualize) {
  const svg = d3.select('#projects-pie-plot');
  const legend = d3.select('.legend');

  svg.selectAll('path').remove();
  legend.selectAll('li').remove();

  const rolledData = d3.rollups(
    projectsToVisualize,
    (values) => values.length,
    (project) => project.year,
  );

  const data = rolledData.map(([year, count]) => ({
    value: count,
    label: year,
  }));

  const sliceGenerator = d3.pie().value((d) => d.value);
  const arcData = sliceGenerator(data);

  svg
    .selectAll('path')
    .data(arcData)
    .join('path')
    .attr('d', arcGenerator)
    .attr('fill', (_d, i) => colors(i))
    .attr('class', (d) => (d.data.label === selectedYear ? 'selected' : null))
    .attr('tabindex', 0)
    .attr('role', 'button')
    .attr('aria-label', (d) => `${d.data.label}: ${d.data.value} projects`)
    .on('click', (_event, d) => {
      selectedYear = selectedYear === d.data.label ? null : d.data.label;
      render();
    })
    .on('keydown', (event, d) => {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        selectedYear = selectedYear === d.data.label ? null : d.data.label;
        render();
      }
    });

  legend
    .selectAll('li')
    .data(data)
    .join('li')
    .attr('style', (_d, i) => `--color: ${colors(i)}`)
    .attr('class', (d) => `legend-item${d.label === selectedYear ? ' selected' : ''}`)
    .attr('tabindex', 0)
    .attr('role', 'button')
    .attr('aria-label', (d) => `Filter to ${d.label} projects`)
    .html((d) => `<span class="swatch"></span>${d.label} <em>(${d.value})</em>`)
    .on('click', (_event, d) => {
      selectedYear = selectedYear === d.label ? null : d.label;
      render();
    })
    .on('keydown', (event, d) => {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        selectedYear = selectedYear === d.label ? null : d.label;
        render();
      }
    });
}

function render() {
  const searchFilteredProjects = getSearchFilteredProjects();
  const availableYears = new Set(searchFilteredProjects.map((project) => project.year));

  if (selectedYear && !availableYears.has(selectedYear)) {
    selectedYear = null;
  }

  const visibleProjects = selectedYear
    ? searchFilteredProjects.filter((project) => project.year === selectedYear)
    : searchFilteredProjects;

  renderProjects(visibleProjects, projectsContainer, 'h2');
  renderPieChart(searchFilteredProjects);
}

searchInput.addEventListener('input', (event) => {
  query = event.target.value;
  render();
});

render();
