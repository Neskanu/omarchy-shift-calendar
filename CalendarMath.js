.pragma library

function pad2(n) {
  var v = Number(n);
  return (v < 10 ? "0" : "") + v;
}

function dateKey(year, month, day) {
  return year + "-" + pad2(Number(month) + 1) + "-" + pad2(day);
}

function keyForDate(date) {
  return dateKey(date.getFullYear(), date.getMonth(), date.getDate());
}

function parseKey(k) {
  if (!k || typeof k !== "string") return new Date();
  var p = k.split("-");
  return new Date(Date.UTC(parseInt(p[0], 10), parseInt(p[1], 10) - 1, parseInt(p[2], 10)));
}

function formatKey(d) {
  return d.getUTCFullYear() + "-" + pad2(d.getUTCMonth() + 1) + "-" + pad2(d.getUTCDate());
}

function addDays(k, n) {
  var d = parseKey(k);
  d.setUTCDate(d.getUTCDate() + n);
  return formatKey(d);
}

function dateRange(k1, k2) {
  var d1 = parseKey(k1);
  var d2 = parseKey(k2);
  var start = d1 <= d2 ? d1 : d2;
  var end = d1 <= d2 ? d2 : d1;
  var list = [];
  var cur = new Date(start.getTime());
  while (cur <= end) {
    list.push(formatKey(cur));
    cur.setUTCDate(cur.getUTCDate() + 1);
  }
  return list;
}

function monthGrid(year, month, weekStart, todayKey) {
  var start = weekStart !== undefined && weekStart !== null ? weekStart : 1;
  var firstDay = new Date(Date.UTC(year, month, 1));
  var leading = (firstDay.getUTCDay() - start + 7) % 7;
  var cursor = new Date(Date.UTC(year, month, 1 - leading));
  var weeks = [];
  for (var w = 0; w < 6; w++) {
    var days = [];
    for (var d = 0; d < 7; d++) {
      var y = cursor.getUTCFullYear();
      var m = cursor.getUTCMonth();
      var day = cursor.getUTCDate();
      var weekday = cursor.getUTCDay();
      var key = dateKey(y, m, day);
      days.push({
        key: key,
        year: y,
        month: m,
        day: day,
        weekday: weekday,
        inMonth: (m === month && y === year),
        isWeekend: (weekday === 0 || weekday === 6),
        isToday: (key === todayKey)
      });
      cursor.setUTCDate(cursor.getUTCDate() + 1);
    }
    weeks.push(days);
  }
  return weeks;
}

function yearMonths(year, weekStart, todayKey) {
  var list = [];
  for (var m = 0; m < 12; m++) {
    list.push({
      month: m,
      year: year,
      weeks: monthGrid(year, m, weekStart, todayKey)
    });
  }
  return list;
}

function countShifts(shifts, year, month) {
  var day = 0;
  var night = 0;
  var off = 0;
  if (!shifts) return { day: 0, night: 0, off: 0, total: 0 };
  var prefix = year + "-";
  if (month !== undefined && month !== null) {
    prefix += pad2(Number(month) + 1) + "-";
  }
  for (var k in shifts) {
    if (k.indexOf(prefix) === 0) {
      var t = shifts[k];
      if (t === "day") day++;
      else if (t === "night") night++;
      else if (t === "off") off++;
    }
  }
  return { day: day, night: night, off: off, total: day + night };
}

function daysBetween(k1, k2) {
  var d1 = parseKey(k1);
  var d2 = parseKey(k2);
  var msPerDay = 24 * 60 * 60 * 1000;
  return Math.round((d2.getTime() - d1.getTime()) / msPerDay);
}

function expandPattern(rleList) {
  var cycle = [];
  if (!rleList || !rleList.length) return cycle;
  for (var i = 0; i < rleList.length; i++) {
    var block = rleList[i];
    var type = block.type || "day";
    var count = Math.max(1, parseInt(block.count, 10) || 1);
    for (var c = 0; c < count; c++) {
      cycle.push(type);
    }
  }
  return cycle;
}

function applyPattern(shifts, startKey, endKey, rleList, anchorKey) {
  var cycle = expandPattern(rleList);
  if (!cycle.length) return shifts;
  var d1 = parseKey(startKey);
  var d2 = parseKey(endKey);
  var rangeStart = d1 <= d2 ? d1 : d2;
  var rangeEnd = d1 <= d2 ? d2 : d1;
  var anchor = anchorKey || startKey;

  var updated = ({});
  for (var k in shifts) {
    updated[k] = shifts[k];
  }

  var cur = new Date(rangeStart.getTime());
  while (cur <= rangeEnd) {
    var curKey = formatKey(cur);
    var delta = daysBetween(anchor, curKey);
    var idx = ((delta % cycle.length) + cycle.length) % cycle.length;
    var shift = cycle[idx];
    if (shift === "none") {
      delete updated[curKey];
    } else {
      updated[curKey] = shift;
    }
    cur.setUTCDate(cur.getUTCDate() + 1);
  }
  return updated;
}

function guessPattern(shifts) {
  if (!shifts) return null;
  var keys = [];
  for (var k in shifts) {
    if (shifts[k] && shifts[k] !== "none") {
      keys.push(k);
    }
  }
  if (keys.length < 4) return null;
  keys.sort();

  var minKey = keys[0];
  var maxKey = keys[keys.length - 1];
  var span = daysBetween(minKey, maxKey) + 1;
  if (span < 4) return null;

  var seq = [];
  for (var i = 0; i < span; i++) {
    var dKey = addDays(minKey, i);
    seq.push(shifts[dKey] || null);
  }

  var known = [];
  for (var s = 0; s < seq.length; s++) {
    if (seq[s] !== null) known.push(s);
  }
  if (known.length < 4) return null;

  var best = null;
  var bestScore = -1;
  var maxP = Math.min(42, Math.max(4, span));

  for (var p = 2; p <= maxP; p++) {
    for (var o = 0; o < p; o++) {
      var pattern = [];
      for (var j = 0; j < p; j++) {
        var counts = { day: 0, night: 0, off: 0 };
        var total = 0;
        for (var ki = 0; ki < known.length; ki++) {
          var idx = known[ki];
          if (((idx - o) % p + p) % p === j) {
            var val = seq[idx];
            if (counts[val] !== undefined) {
              counts[val]++;
              total++;
            }
          }
        }
        if (total > 0) {
          var maj = "off";
          var maxC = -1;
          for (var t in counts) {
            if (counts[t] > maxC) {
              maxC = counts[t];
              maj = t;
            }
          }
          pattern.push(maj);
        } else {
          pattern.push("off");
        }
      }

      var matches = 0;
      for (var mi = 0; mi < known.length; mi++) {
        var kidx = known[mi];
        var patIdx = ((kidx - o) % p + p) % p;
        if (seq[kidx] === pattern[patIdx]) matches++;
      }
      var ratio = matches / known.length;
      var score = ratio - (p * 0.002);
      if (ratio >= 0.80 && score > bestScore) {
        bestScore = score;
        best = {
          period: p,
          offset: o,
          ratio: ratio,
          pattern: pattern,
          anchorDate: addDays(minKey, o)
        };
      }
    }
  }

  if (!best) return null;

  // Run-length encode consensus pattern
  var rle = [];
  var currType = best.pattern[0];
  var currLen = 1;
  for (var pi = 1; pi < best.pattern.length; pi++) {
    if (best.pattern[pi] === currType) {
      currLen++;
    } else {
      rle.push({ type: currType, count: currLen });
      currType = best.pattern[pi];
      currLen = 1;
    }
  }
  rle.push({ type: currType, count: currLen });
  best.rle = rle;
  return best;
}
