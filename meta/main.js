import * as d3 from 'https://cdn.jsdelivr.net/npm/d3@7.9.0/+esm';
import scrollama from 'https://cdn.jsdelivr.net/npm/scrollama@3.2.0/+esm';

const REPO_URL = 'https://github.com/xibahbah/porfolio';
const CHART = {
  width: 1000,
  height: 600,
  margin: { top: 20, right: 30, bottom: 45, left: 60 },
};

let xScale;
let yScale;
let timeScale;
let commits = [];
let filteredCommits = [];
let commitProgress = 100;
let commitMaxTime;

const colors = d3.scaleOrdinal(d3.schemeTableau10);

async function loadData() {
  return d3.csv('loc.csv', (row) => ({
    ...row,
    line: Number(row.line),
    depth: Number(row.depth),
    length: Number(row.length),
    date: new Date(`${row.date}T00:00${row.timezone}`),
    datetime: new Date(row.datetime),
  }));
}

function processCommits(data) {
  return d3
    .groups(data, (d) => d.commit)
    .map(([commit, lines]) => {
      const first = lines[0];
      const { author, date, time, timezone, datetime } = first;

      return {
        id: commit,
        url: `${REPO_URL}/commit/${commit}`,
        author,
        date,
        time,
        timezone,
        datetime,
        hourFrac:
          datetime.getHours() +
          datetime.getMinutes() / 60 +
          datetime.getSeconds() / 3600,
        totalLines: lines.length,
        lines,
      };
    })
    .sort((a, b) => d3.ascending(a.datetime, b.datetime));
}

function usableArea() {
  const { width, height, margin } = CHART;
  return {
    top: margin.top,
    right: width - margin.right,
    bottom: height - margin.bottom,
    left: margin.left,
    width: width - margin.left - margin.right,
    height: height - margin.top - margin.bottom,
  };
}

function safeTimeDomain(commitData) {
  const extent = d3.extent(commitData, (d) => d.datetime);
  if (!extent[0] || !extent[1]) {
    return timeScale.domain();
  }
  if (+extent[0] === +extent[1]) {
    return [
      d3.timeDay.offset(extent[0], -1),
      d3.timeDay.offset(extent[1], 1),
    ];
  }
  return extent;
}

function radiusScale(commitData) {
  const [minLines = 1, maxLines = 1] = d3.extent(commitData, (d) => d.totalLines);
  return d3
    .scaleSqrt()
    .domain([minLines, maxLines])
    .range(minLines === maxLines ? [10, 10] : [4, 28]);
}

function renderStats(lineData, commitData) {
  const stats = document.querySelector('#stats');
  const files = new Set(lineData.map((d) => d.file));
  const languages = new Set(lineData.map((d) => d.type));
  const longestFile = d3.greatest(
    d3.rollups(
      lineData,
      (values) => values.length,
      (d) => d.file,
    ),
    (d) => d[1],
  );
  const longestLine = d3.greatest(lineData, (d) => d.length);
  const deepestLine = d3.greatest(lineData, (d) => d.depth);
  const workByPeriod = d3.rollups(
    lineData,
    (values) => values.length,
    (d) => d.datetime.toLocaleString('en', { dayPeriod: 'short' }),
  );
  const maxPeriod = d3.greatest(workByPeriod, (d) => d[1])?.[0] ?? 'None yet';

  stats.innerHTML = `
    <dl class="stats">
      <dt>Lines of code</dt>
      <dd>${lineData.length}</dd>

      <dt>Files</dt>
      <dd>${files.size}</dd>

      <dt>Commits</dt>
      <dd>${commitData.length}</dd>

      <dt>Languages</dt>
      <dd>${languages.size}</dd>

      <dt>Longest file</dt>
      <dd>${longestFile ? `${longestFile[0]} (${longestFile[1]} lines)` : 'None yet'}</dd>

      <dt>Longest line</dt>
      <dd>${longestLine ? `${longestLine.file}:${longestLine.line} (${longestLine.length} chars)` : 'None yet'}</dd>

      <dt>Deepest line</dt>
      <dd>${deepestLine ? `${deepestLine.file}:${deepestLine.line} (depth ${deepestLine.depth})` : 'None yet'}</dd>

      <dt>Busiest time</dt>
      <dd>${maxPeriod}</dd>
    </dl>
  `;
}

function renderTooltipContent(commit) {
  if (!commit || Object.keys(commit).length === 0) return;

  document.getElementById('commit-link').href = commit.url;
  document.getElementById('commit-link').textContent = commit.id;
  document.getElementById('commit-date').textContent =
    commit.datetime.toLocaleString('en', { dateStyle: 'full' });
  document.getElementById('commit-tooltip-time').textContent =
    commit.datetime.toLocaleString('en', { timeStyle: 'short' });
  document.getElementById('commit-author').textContent = commit.author;
  document.getElementById('commit-lines').textContent = commit.totalLines;
}

function updateTooltipVisibility(isVisible) {
  document.getElementById('commit-tooltip').hidden = !isVisible;
}

function updateTooltipPosition(event) {
  const tooltip = document.getElementById('commit-tooltip');
  tooltip.style.left = `${event.clientX + 12}px`;
  tooltip.style.top = `${event.clientY + 12}px`;
}

function isCommitSelected(selection, commit) {
  if (!selection) {
    return false;
  }

  const [[x0, y0], [x1, y1]] = selection;
  const x = xScale(commit.datetime);
  const y = yScale(commit.hourFrac);

  return x >= x0 && x <= x1 && y >= y0 && y <= y1;
}

function renderSelectionCount(selection) {
  const selectedCommits = selection
    ? filteredCommits.filter((commit) => isCommitSelected(selection, commit))
    : [];
  const countElement = document.querySelector('#selection-count');

  countElement.textContent = `${selectedCommits.length || 'No'} commits selected`;
  return selectedCommits;
}

function renderLanguageBreakdown(selection) {
  const selectedCommits = selection
    ? filteredCommits.filter((commit) => isCommitSelected(selection, commit))
    : [];
  const container = document.querySelector('#language-breakdown');

  if (selectedCommits.length === 0) {
    container.innerHTML = '';
    return;
  }

  const lines = selectedCommits.flatMap((commit) => commit.lines);
  const breakdown = d3.rollup(
    lines,
    (values) => values.length,
    (d) => d.type,
  );

  container.innerHTML = '';
  for (const [language, count] of breakdown) {
    const proportion = count / lines.length;
    const formatted = d3.format('.1~%')(proportion);

    container.innerHTML += `
      <dt>${language}</dt>
      <dd>${count} lines (${formatted})</dd>
    `;
  }
}

function brushed(event) {
  const selection = event.selection;

  d3.selectAll('#chart circle').classed('selected', (commit) =>
    isCommitSelected(selection, commit),
  );
  renderSelectionCount(selection);
  renderLanguageBreakdown(selection);
}

function drawCircles(dots, commitData) {
  const rScale = radiusScale(commitData);
  const sortedCommits = d3.sort(commitData, (d) => -d.totalLines);

  dots
    .selectAll('circle')
    .data(sortedCommits, (d) => d.id)
    .join('circle')
    .attr('cx', (d) => xScale(d.datetime))
    .attr('cy', (d) => yScale(d.hourFrac))
    .attr('r', (d) => rScale(d.totalLines))
    .attr('fill', 'steelblue')
    .style('fill-opacity', 0.7)
    .style('--r', (d) => rScale(d.totalLines))
    .on('mouseenter', (event, commit) => {
      d3.select(event.currentTarget).style('fill-opacity', 1);
      renderTooltipContent(commit);
      updateTooltipVisibility(true);
      updateTooltipPosition(event);
    })
    .on('mousemove', updateTooltipPosition)
    .on('mouseleave', (event) => {
      d3.select(event.currentTarget).style('fill-opacity', 0.7);
      updateTooltipVisibility(false);
    });
}

function renderScatterPlot(commitData) {
  const { width, height } = CHART;
  const area = usableArea();

  document.querySelector('#chart').innerHTML = '';

  const svg = d3
    .select('#chart')
    .append('svg')
    .attr('viewBox', `0 0 ${width} ${height}`)
    .style('overflow', 'visible');

  xScale = d3
    .scaleTime()
    .domain(safeTimeDomain(commitData))
    .range([area.left, area.right])
    .nice();

  yScale = d3
    .scaleLinear()
    .domain([0, 24])
    .range([area.bottom, area.top]);

  svg
    .append('g')
    .attr('class', 'gridlines')
    .attr('transform', `translate(${area.left}, 0)`)
    .call(d3.axisLeft(yScale).tickFormat('').tickSize(-area.width));

  svg
    .append('g')
    .attr('class', 'x-axis')
    .attr('transform', `translate(0, ${area.bottom})`)
    .call(d3.axisBottom(xScale));

  svg
    .append('g')
    .attr('class', 'y-axis')
    .attr('transform', `translate(${area.left}, 0)`)
    .call(
      d3
        .axisLeft(yScale)
        .tickFormat((d) => `${String(d % 24).padStart(2, '0')}:00`),
    );

  svg.append('g').attr('class', 'dots');
  drawCircles(svg.select('g.dots'), commitData);

  svg.call(
    d3
      .brush()
      .extent([
        [area.left, area.top],
        [area.right, area.bottom],
      ])
      .on('start brush end', brushed),
  );

  svg.selectAll('.dots, .overlay ~ *').raise();
}

function updateScatterPlot(commitData) {
  const area = usableArea();
  const svg = d3.select('#chart').select('svg');

  xScale.domain(safeTimeDomain(commitData)).nice();

  svg.select('g.x-axis').call(d3.axisBottom(xScale));
  svg
    .select('g.gridlines')
    .call(d3.axisLeft(yScale).tickFormat('').tickSize(-area.width));
  drawCircles(svg.select('g.dots'), commitData);
  renderSelectionCount(null);
  renderLanguageBreakdown(null);
}

function updateFileDisplay(commitData) {
  const lines = commitData.flatMap((commit) => commit.lines);
  const files = d3
    .groups(lines, (d) => d.file)
    .map(([name, fileLines]) => ({ name, lines: fileLines }))
    .sort((a, b) => b.lines.length - a.lines.length);

  const filesContainer = d3
    .select('#files')
    .selectAll('div')
    .data(files, (d) => d.name)
    .join(
      (enter) =>
        enter.append('div').call((div) => {
          const term = div.append('dt');
          term.append('code');
          term.append('small');
          div.append('dd');
        }),
      (update) => update,
      (exit) => exit.remove(),
    );

  filesContainer
    .select('dt > code')
    .text((d) => d.name);

  filesContainer
    .select('dt > small')
    .text((d) => `${d.lines.length} lines`);

  filesContainer
    .select('dd')
    .selectAll('div')
    .data((d) => d.lines, (d) => `${d.commit}-${d.file}-${d.line}`)
    .join('div')
    .attr('class', 'loc')
    .attr('title', (d) => `${d.type}: ${d.file}:${d.line}`)
    .attr('style', (d) => `--color: ${colors(d.type)}`);
}

function updateEverything(nextCommits) {
  filteredCommits = nextCommits;
  const lines = filteredCommits.flatMap((commit) => commit.lines);

  renderStats(lines, filteredCommits);
  updateScatterPlot(filteredCommits);
  updateFileDisplay(filteredCommits);
}

function updateTimeDisplay() {
  document.querySelector('#commit-time').dateTime = commitMaxTime.toISOString();
  document.querySelector('#commit-time').textContent = commitMaxTime.toLocaleString(
    'en',
    { dateStyle: 'long', timeStyle: 'short' },
  );
}

function onTimeSliderChange() {
  const slider = document.querySelector('#commit-progress');
  commitProgress = Number(slider.value);
  commitMaxTime = timeScale.invert(commitProgress);
  updateTimeDisplay();
  updateEverything(commits.filter((d) => d.datetime <= commitMaxTime));
}

function setProgressFromCommit(commit) {
  commitProgress = timeScale(commit.datetime);
  commitMaxTime = commit.datetime;
  document.querySelector('#commit-progress').value = commitProgress;
  updateTimeDisplay();
  updateEverything(commits.filter((d) => d.datetime <= commitMaxTime));
}

function renderCommitStory(commitData) {
  d3.select('#scatter-story')
    .selectAll('.step')
    .data(commitData, (d) => d.id)
    .join('div')
    .attr('class', 'step')
    .html(
      (d, i) => `
        <p class="step-kicker">Commit ${i + 1} of ${commitData.length}</p>
        <p>
          On ${d.datetime.toLocaleString('en', {
            dateStyle: 'full',
            timeStyle: 'short',
          })}, I made
          <a href="${d.url}" target="_blank" rel="noopener noreferrer">${
            i > 0 ? 'another commit' : 'my first commit'
          }</a>.
        </p>
        <p>
          This commit touched ${d.totalLines} lines across ${
            d3.rollups(
              d.lines,
              (values) => values.length,
              (line) => line.file,
            ).length
          } files.
        </p>
      `,
    );
}

function setupScrollytelling() {
  const scroller = scrollama();

  function onStepEnter(response) {
    const commit = response.element.__data__;
    d3.selectAll('#scatter-story .step').classed('is-active', false);
    d3.select(response.element).classed('is-active', true);
    setProgressFromCommit(commit);
  }

  scroller
    .setup({
      container: '#scrolly-1',
      step: '#scrolly-1 .step',
      offset: 0.55,
    })
    .onStepEnter(onStepEnter);

  window.addEventListener('resize', scroller.resize);
}

const data = await loadData();
commits = processCommits(data);
filteredCommits = commits;
timeScale = d3
  .scaleTime()
  .domain(d3.extent(commits, (d) => d.datetime))
  .range([0, 100]);
commitMaxTime = timeScale.invert(commitProgress);

renderStats(data, commits);
renderScatterPlot(commits);
updateFileDisplay(commits);
renderCommitStory(commits);
updateTimeDisplay();
setupScrollytelling();

document
  .querySelector('#commit-progress')
  .addEventListener('input', onTimeSliderChange);
