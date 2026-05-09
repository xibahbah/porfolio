import * as d3 from 'https://cdn.jsdelivr.net/npm/d3@7.9.0/+esm';

const REPO_URL = 'https://github.com/xibahbah/porfolio';

let xScale;
let yScale;
let commits = [];

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

function renderStats(data, commitData) {
  const stats = document.querySelector('#stats');
  const files = new Set(data.map((d) => d.file));
  const languages = new Set(data.map((d) => d.type));
  const longestFile = d3.greatest(
    d3.rollups(
      data,
      (values) => values.length,
      (d) => d.file,
    ),
    (d) => d[1],
  );
  const longestLine = d3.greatest(data, (d) => d.length);
  const deepestLine = d3.greatest(data, (d) => d.depth);
  const workByPeriod = d3.rollups(
    data,
    (values) => values.length,
    (d) => d.datetime.toLocaleString('en', { dayPeriod: 'short' }),
  );
  const maxPeriod = d3.greatest(workByPeriod, (d) => d[1])?.[0];

  stats.innerHTML = `
    <dl class="stats">
      <dt>Lines of code</dt>
      <dd>${data.length}</dd>

      <dt>Files</dt>
      <dd>${files.size}</dd>

      <dt>Commits</dt>
      <dd>${commitData.length}</dd>

      <dt>Languages</dt>
      <dd>${languages.size}</dd>

      <dt>Longest file</dt>
      <dd>${longestFile?.[0]} (${longestFile?.[1]} lines)</dd>

      <dt>Longest line</dt>
      <dd>${longestLine?.file}:${longestLine?.line} (${longestLine?.length} chars)</dd>

      <dt>Deepest line</dt>
      <dd>${deepestLine?.file}:${deepestLine?.line} (depth ${deepestLine?.depth})</dd>

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
  document.getElementById('commit-time').textContent =
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
    ? commits.filter((commit) => isCommitSelected(selection, commit))
    : [];
  const countElement = document.querySelector('#selection-count');

  countElement.textContent = `${selectedCommits.length || 'No'} commits selected`;
  return selectedCommits;
}

function renderLanguageBreakdown(selection) {
  const selectedCommits = selection
    ? commits.filter((commit) => isCommitSelected(selection, commit))
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

function renderScatterPlot(commitData) {
  const width = 1000;
  const height = 600;
  const margin = { top: 20, right: 30, bottom: 45, left: 60 };
  const usableArea = {
    top: margin.top,
    right: width - margin.right,
    bottom: height - margin.bottom,
    left: margin.left,
    width: width - margin.left - margin.right,
    height: height - margin.top - margin.bottom,
  };

  document.querySelector('#chart').innerHTML = '';

  const svg = d3
    .select('#chart')
    .append('svg')
    .attr('viewBox', `0 0 ${width} ${height}`)
    .style('overflow', 'visible');

  xScale = d3
    .scaleTime()
    .domain(d3.extent(commitData, (d) => d.datetime))
    .range([usableArea.left, usableArea.right])
    .nice();

  yScale = d3
    .scaleLinear()
    .domain([0, 24])
    .range([usableArea.bottom, usableArea.top]);

  const [minLines, maxLines] = d3.extent(commitData, (d) => d.totalLines);
  const rScale = d3
    .scaleSqrt()
    .domain([minLines, maxLines])
    .range([4, 28]);
  const sortedCommits = d3.sort(commitData, (d) => -d.totalLines);

  svg
    .append('g')
    .attr('class', 'gridlines')
    .attr('transform', `translate(${usableArea.left}, 0)`)
    .call(d3.axisLeft(yScale).tickFormat('').tickSize(-usableArea.width));

  svg
    .append('g')
    .attr('transform', `translate(0, ${usableArea.bottom})`)
    .call(d3.axisBottom(xScale));

  svg
    .append('g')
    .attr('transform', `translate(${usableArea.left}, 0)`)
    .call(
      d3
        .axisLeft(yScale)
        .tickFormat((d) => `${String(d % 24).padStart(2, '0')}:00`),
    );

  const dots = svg.append('g').attr('class', 'dots');

  dots
    .selectAll('circle')
    .data(sortedCommits)
    .join('circle')
    .attr('cx', (d) => xScale(d.datetime))
    .attr('cy', (d) => yScale(d.hourFrac))
    .attr('r', (d) => rScale(d.totalLines))
    .attr('fill', 'steelblue')
    .style('fill-opacity', 0.7)
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

  svg.call(
    d3
      .brush()
      .extent([
        [usableArea.left, usableArea.top],
        [usableArea.right, usableArea.bottom],
      ])
      .on('start brush end', brushed),
  );

  svg.selectAll('.dots, .overlay ~ *').raise();
}

const data = await loadData();
commits = processCommits(data);

renderStats(data, commits);
renderScatterPlot(commits);
