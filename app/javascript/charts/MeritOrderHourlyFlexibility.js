/* globals _ */

import * as d3 from './d3';
import HourlyBase from './HourlyBase';
import negativeRegionRect from './utils/negativeRegionRect';

class MeritOrderHourlyFlexibility extends HourlyBase {
  filterYValue(serie, value) {
    return serie && serie.key === 'total_demand' ? value : -value;
  }

  draw() {
    super.draw();
    this.drawLegend(this.series);

    // Add a "negative region" which shades area of the chart representing values below zero.
    const [negativeRect, updateNegativeRect] = negativeRegionRect(this.width, this.yScale);

    this.updateNegativeRegion = updateNegativeRect;
    this.svg.node().append(negativeRect);
  }

  /**
   * A custom offset function which stacks series above and below the total demand line
   *
   * Series with positive values will appear above the total demand, while those with negative
   * values appear below.
   */
  stackOffset() {
    return (series, order) => {
      d3.stackOffsetDiverging(series, order);

      const lastId = this.chartData.length - 1;
      const demandValues = this.chartData[lastId].values;

      for (const [i, demandValue] of demandValues.entries()) {
        const baseline = demandValue.y;

        for (let serieData of series) {
          serieData[i][0] += baseline;
          serieData[i][1] += baseline;
        }
      }
    };
  }

  drawData(xScale, yScale, area, line) {
    this.svg
      .selectAll('path.serie')
      .data(this.stackedData)
      .enter()
      .append('g')
      .attr('id', (data, index) => `path_${index}`)
      .attr('class', 'serie')
      .append('path')
      .attr('class', 'area')
      .attr('d', (data) => area(data))
      .attr('fill', (data) => this.serieValue(data.key, 'color'))
      .attr('data-tooltip-textonly', true)
      .attr('data-tooltip-text', (data) => this.serieValue(data.key, 'label'));

    this.svg
      .selectAll('path.serie')
      .data(this.totalDemand)
      .enter()
      .append('g')
      .attr('id', (data, index) => `path_${index}`)
      .attr('clip-path', 'url(#clip_' + this.chartContainerId() + ')')
      .attr('class', 'serie-line')
      .append('path')
      .attr('class', 'line')
      .attr('d', (data) => line(data.values))
      .attr('stroke', (data) => data.color)
      .attr('stroke-width', 2)
      .attr('fill', 'none');
  }

  refresh(...args) {
    super.refresh(...args);

    this.setStackedData();

    const xScale = this.createTimeScale(this.dateSelect.currentRange());
    const yScale = this.createLinearScale();
    const area = this.area(xScale, yScale);
    const line = this.line(xScale, yScale);

    this.svg.select('.x_axis').call(this.createTimeAxis(xScale));
    this.svg.select('.y_axis').call(this.createLinearAxis(yScale));

    this.updateNegativeRegion(yScale, d3.transition().duration(0));

    if (this.containerNode().find('g.serie-line').length > 0) {
      this.svg
        .selectAll('g.serie')
        .data(this.stackedData)
        .select('path.area')
        .attr('fill', (data) => this.serieValue(data.key, 'color'))
        .attr('opacity', (data) => (this.serieValue(data.key, 'hidden') ? 0 : 1))
        .attr('d', (data) => area(data));

      return this.svg
        .selectAll('g.serie-line')
        .data(this.totalDemand)
        .select('path.line')
        .attr('d', (data) => line(data.values))
        .attr('opacity', (data) => (this.serieValue(data.key, 'hidden') ? 0 : 1));
    } else {
      return this.drawData(xScale, yScale, area, line);
    }
  }

  area(xScale, yScale) {
    return d3
      .area()
      .curve(d3.curveMonotoneX)
      .x((data) => xScale(data.data.x))
      .y0((data) => yScale(data[0]))
      .y1((data) => yScale(data[1]));
  }

  line(xScale, yScale) {
    return d3
      .line()
      .curve(d3.curveMonotoneX)
      .x((data) => xScale(data.x))
      .y((data) => yScale(data.y));
  }

  extent() {
    const targetKeys = this.model.target_series().map((s) => s.get('gquery_key'));
    const grouped = _.groupBy(this.visibleData(), (d) => _.contains(targetKeys, d.key));

    const targets = _.pluck(grouped[true], 'values');
    const series = _.pluck(grouped[false], 'values');

    let min = 0;
    let max = 0;

    for (var index = 0; index < series[0].length; index++) {
      const maxTargetLoad = d3.max(targets, (s) => s[index]);
      const minTargetLoad = d3.min(targets, (s) => s[index]);

      // Values above zero are ignored as values in the charts are inverted from the original
      // (negative values [discharging] become positive, positive [charging] become negative).
      const posAggregateLoad =
        d3.sum(series, (s) => (s[index] >= 0 ? 0 : -s[index])) + maxTargetLoad;

      const negAggregateLoad =
        d3.sum(series, (s) => (s[index] <= 0 ? 0 : -s[index])) + minTargetLoad;

      max = Math.max(max, posAggregateLoad, maxTargetLoad);
      min = Math.min(min, negAggregateLoad, minTargetLoad);
    }

    return [min, max];
  }

  minYValue() {
    const [min] = this.extent();
    return min;
  }

  maxYValue() {
    const [, max] = this.extent();
    return max;
  }
}

export default MeritOrderHourlyFlexibility;
