//= require ./namespace

function formatCocLabel(text, width, padding) {
  text.each(function () {
    const paddingV = width * padding;
    const widthV = width - paddingV;
    const text = d3.select(this);
    const [coc, projectName] = text.text().split('|||');
    const y = text.attr('y');
    const lineHeight = 1.2; // ems

    text.text(null);

    text
      .append('tspan')
      .attr('x', -paddingV)
      .attr('y', y)
      .attr('font-weight', 'bold')
      .attr('fill', '#555')
      .text(coc);
    text
      .append('tspan')
      .attr('x', -paddingV)
      .attr('y', y)
      .attr('dy', lineHeight + 'em')
      .attr('fill', '#333')
      .text(projectName.slice(0, 30) + '…');

    return;
  });
}

const barSize = 35;
const barPaddingInner = 0.75;
const barPaddingOuter = 0.25;
App.WarehouseReports.ClientTimelineChart = (options) => {
  const wrapper = document.querySelector(options.rootSelector);
  const { width } = wrapper.getBoundingClientRect();
  const margin = { top: 0, bottom: 20, left: 200, right: 0 };
  const height = options.enrollments.length * barSize + margin.bottom + margin.top;
  const plotWidth = width - (margin.left + margin.right);
  const plotHeight = height - (margin.top + margin.bottom);
  const cocCodes = options.cocs.map((d) => d.code);

  const domain = options.domain.map((s) => d3.isoParse(s));
  const enrollments = options.enrollments.map((enrollment, idx) => ({
    ...enrollment,
    id: idx,
    history: enrollment.history.map((evt) => ({
      cocCode: enrollment.coc,
      from: d3.isoParse(evt.from),
      to: d3.isoParse(evt.to),
    })),
  }));

  const xScale = d3.scaleTime().domain(domain).rangeRound([0, plotWidth]);
  const yScale = d3
    .scaleBand()
    .domain(enrollments.map((d) => d.id))
    .range([plotHeight, 0])
    .paddingInner(barPaddingInner)
    .paddingOuter(barPaddingOuter);

  const svg = d3
    .select(options.rootSelector)
    .append('svg')
    .attr('width', width)
    .attr('height', height);

  const xAxis = svg
    .append('g')
    .attr('class', 'axis')
    .attr('transform', `translate(${margin.left},${margin.top + plotHeight})`)
    .call(d3.axisBottom(xScale).tickFormat(d3.timeFormat('%m/%y')));

  xAxis
    .selectAll('line')
    .attr('stroke', '#ccc')
    .attr('stroke-dasharray', '4')
    .each(function (_, i) {
      d3.select(this).attr('y2', i % 2 ? -1 * (plotHeight - 1) : 0);
    });

  const yAxis = svg
    .append('g')
    .attr('class', 'axis')
    .attr('transform', `translate(${margin.left},${margin.top})`)
    .call(
      d3
        .axisLeft(yScale)
        .tickPadding(10)
        .tickFormat((d, i) => enrollments[i].coc)
        .tickFormat((d, i) => {
          const { coc, project_name } = enrollments[i];
          return `${coc}|||${project_name}`;
        }),
    );
  yAxis.selectAll('.tick text').call(formatCocLabel, margin.left, 0.1);
  yAxis
    .selectAll('line')
    .attr('transform', `translate(${plotWidth},0)`)
    .attr('x2', -1 * (plotWidth - 1))
    .attr('stroke', '#ccc');

  svg
    .append('g')
    .attr('class', 'chart')
    .attr('transform', `translate(${margin.left},${margin.top})`)
    .selectAll('g')
    .data(enrollments)
    .enter()
    .append('g')
    .attr('transform', function (d, i) {
      return `translate(0,${yScale(d.id)})`;
    })
    .selectAll('rect')
    .data((d) => d.history)
    .enter()
    .append('rect')
    .attr('x', (d) => xScale(d.from))
    .attr('width', (d) => xScale(d.to) - xScale(d.from))
    .attr('height', yScale.bandwidth())
    .attr('class', (d) => `c-swatch__display--fill-${cocCodes.indexOf(d.cocCode)}`);
};
