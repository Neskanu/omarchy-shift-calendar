#!/usr/bin/env python3
"""
Generates a printable 12-month calendar with work shifts marked,
styled for high-quality landscape printing (A4/Letter) and screen viewing.
"""

import sys
import os
import json
import calendar
import datetime
import subprocess

LOCALES_MONTHS = {
    "en": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
    "de": ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"],
    "es": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"],
    "fr": ["Janvier", "Février", "Mars", "Avril", "Mai", "Juin", "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"],
    "it": ["Gennaio", "Febbraio", "Marzo", "Aprile", "Maggio", "Giugno", "Luglio", "Agosto", "Settembre", "Ottobre", "Novembre", "Dicembre"],
    "ru": ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"],
    "zh": ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"],
    "ja": ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"],
    "pt": ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
}

LOCALES_WEEKDAYS = {
    "en": ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"],
    "de": ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"],
    "es": ["Lu", "Ma", "Mi", "Ju", "Vi", "Sá", "Do"],
    "fr": ["Lu", "Ma", "Me", "Je", "Ve", "Sa", "Di"],
    "it": ["Lu", "Ma", "Me", "Gi", "Ve", "Sa", "Do"],
    "ru": ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"],
    "zh": ["一", "二", "三", "四", "五", "六", "日"],
    "ja": ["月", "火", "水", "木", "金", "土", "日"],
    "pt": ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
}

LOCALES_LABELS = {
    "en": {"title": "Work Shift Calendar", "day_shift": "Day Shift", "night_shift": "Night Shift", "day_off": "Day Off", "total_shifts": "Total Work Shifts", "print_btn": "Print Calendar / Save PDF"},
    "de": {"title": "Schichtkalender", "day_shift": "Tagschicht", "night_shift": "Nachtschicht", "day_off": "Freier Tag", "total_shifts": "Gesamtarbeitsschichten", "print_btn": "Drucken / PDF speichern"},
    "es": {"title": "Calendario de Turnos", "day_shift": "Turno de Día", "night_shift": "Turno de Noche", "day_off": "Día Libre", "total_shifts": "Total de Turnos", "print_btn": "Imprimir / Guardar PDF"},
    "fr": {"title": "Calendrier de Quarts", "day_shift": "Quart de Jour", "night_shift": "Quart de Nuit", "day_off": "Jour de Repos", "total_shifts": "Total des Quarts", "print_btn": "Imprimer / Enregistrer PDF"},
    "it": {"title": "Calendario Turni", "day_shift": "Turno Diurno", "night_shift": "Turno Notturno", "day_off": "Giorno Libero", "total_shifts": "Totale Turni", "print_btn": "Stampa / Salva PDF"},
    "ru": {"title": "График смен", "day_shift": "Дневная смена", "night_shift": "Ночная смена", "day_off": "Выходной", "total_shifts": "Всего смен", "print_btn": "Печать / Сохранить в PDF"},
    "zh": {"title": "排班日历", "day_shift": "白班", "night_shift": "夜班", "day_off": "休息", "total_shifts": "总班次", "print_btn": "打印 / 导出 PDF"},
    "ja": {"title": "シフトカレンダー", "day_shift": "日勤", "night_shift": "夜勤", "day_off": "休日", "total_shifts": "総シフト数", "print_btn": "印刷 / PDF保存"},
    "pt": {"title": "Calendário de Turnos", "day_shift": "Turno Diurno", "night_shift": "Turno Noturno", "day_off": "Folga", "total_shifts": "Total de Turnos", "print_btn": "Imprimir / Salvar PDF"}
}

def main():
    now = datetime.datetime.now()
    year = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else now.year
    lang = sys.argv[2] if len(sys.argv) > 2 else "en"
    base_lang = lang.split("-")[0].lower()

    month_names = LOCALES_MONTHS.get(base_lang, LOCALES_MONTHS["en"])
    weekday_names = LOCALES_WEEKDAYS.get(base_lang, LOCALES_WEEKDAYS["en"])
    labels = LOCALES_LABELS.get(base_lang, LOCALES_LABELS["en"])

    shifts_file = os.path.expanduser("~/.config/omarchy/shifts.json")
    shifts = {}
    if os.path.exists(shifts_file):
        try:
            with open(shifts_file, "r", encoding="utf-8") as f:
                shifts = json.load(f)
        except Exception as e:
            print(f"Error loading shifts: {e}", file=sys.stderr)

    # Count annual shifts
    annual_days = 0
    annual_nights = 0
    annual_offs = 0

    for key, shift_type in shifts.items():
        if key.startswith(f"{year}-"):
            if shift_type == "day":
                annual_days += 1
            elif shift_type == "night":
                annual_nights += 1
            elif shift_type == "off":
                annual_offs += 1

    total_worked = annual_days + annual_nights

    # Generate months
    cal = calendar.Calendar(firstweekday=0) # Monday first
    months_html = []

    for month_idx in range(1, 13):
        m_name = month_names[month_idx - 1]
        month_days = cal.monthdayscalendar(year, month_idx)
        
        m_days = 0
        m_nights = 0
        m_offs = 0

        rows_html = []
        for week in month_days:
            cells_html = []
            for day in week:
                if day == 0:
                    cells_html.append('<td class="empty-cell"></td>')
                else:
                    date_key = f"{year}-{month_idx:02d}-{day:02d}"
                    st = shifts.get(date_key, "")
                    cls = "day-cell"
                    badge_html = ""
                    if st == "day":
                        cls += " shift-day"
                        badge_html = '<span class="shift-badge">☀️</span>'
                        m_days += 1
                    elif st == "night":
                        cls += " shift-night"
                        badge_html = '<span class="shift-badge">🌙</span>'
                        m_nights += 1
                    elif st == "off":
                        cls += " shift-off"
                        badge_html = '<span class="shift-badge">🏖️</span>'
                        m_offs += 1

                    cells_html.append(f'<td class="{cls}"><span class="day-num">{day}</span>{badge_html}</td>')
            rows_html.append(f"<tr>{''.join(cells_html)}</tr>")

        month_html = f"""
        <div class="month-card">
            <div class="month-header">
                <h3>{m_name}</h3>
                <span class="month-subtotal">☀️ {m_days} &nbsp; 🌙 {m_nights} &nbsp; 🏖️ {m_offs}</span>
            </div>
            <table class="month-table">
                <thead>
                    <tr>{''.join(f'<th>{w}</th>' for w in weekday_names)}</tr>
                </thead>
                <tbody>
                    {''.join(rows_html)}
                </tbody>
            </table>
        </div>
        """
        months_html.append(month_html)

    html_content = f"""<!DOCTYPE html>
<html lang="{base_lang}">
<head>
<meta charset="utf-8">
<title>{labels['title']} - {year}</title>
<style>
    :root {{
        --font: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        --bg: #f8fafc;
        --card-bg: #ffffff;
        --text: #0f172a;
        --muted: #64748b;
        --border: #e2e8f0;
        
        --day-bg: #fef3c7;
        --day-border: #f59e0b;
        --day-text: #92400e;
        
        --night-bg: #ede9fe;
        --night-border: #8b5cf6;
        --night-text: #5b21b6;
        
        --off-bg: #d1fae5;
        --off-border: #10b981;
        --off-text: #065f46;
    }}

    @page {{
        size: A4 landscape;
        margin: 6mm 8mm;
    }}

    * {{
        box-sizing: border-box;
        margin: 0;
        padding: 0;
    }}

    body {{
        font-family: var(--font);
        background: var(--bg);
        color: var(--text);
        padding: 16px 20px;
        -webkit-print-color-adjust: exact !important;
        print-color-adjust: exact !important;
    }}

    .no-print-bar {{
        display: flex;
        align-items: center;
        justify-content: space-between;
        background: #1e293b;
        color: #f8fafc;
        padding: 12px 20px;
        border-radius: 10px;
        margin-bottom: 20px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.1);
    }}

    .print-btn {{
        background: #3b82f6;
        color: white;
        border: none;
        padding: 8px 18px;
        font-size: 14px;
        font-weight: 600;
        border-radius: 6px;
        cursor: pointer;
        display: inline-flex;
        align-items: center;
        gap: 8px;
        transition: background 0.15s;
    }}
    .print-btn:hover {{
        background: #2563eb;
    }}

    .header {{
        display: flex;
        justify-content: space-between;
        align-items: flex-end;
        border-bottom: 2px solid var(--border);
        padding-bottom: 10px;
        margin-bottom: 14px;
    }}

    .header-title h1 {{
        font-size: 26px;
        font-weight: 800;
        letter-spacing: -0.5px;
    }}

    .legend {{
        display: flex;
        align-items: center;
        gap: 16px;
        font-size: 13px;
        font-weight: 600;
    }}

    .legend-item {{
        display: flex;
        align-items: center;
        gap: 6px;
        padding: 4px 10px;
        border-radius: 6px;
        border: 1px solid;
    }}
    .legend-item.day {{ background: var(--day-bg); border-color: var(--day-border); color: var(--day-text); }}
    .legend-item.night {{ background: var(--night-bg); border-color: var(--night-border); color: var(--night-text); }}
    .legend-item.off {{ background: var(--off-bg); border-color: var(--off-border); color: var(--off-text); }}
    .legend-item.total {{ background: #f1f5f9; border-color: #cbd5e1; color: var(--text); }}

    .grid {{
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 12px;
    }}

    .month-card {{
        background: var(--card-bg);
        border: 1px solid var(--border);
        border-radius: 8px;
        padding: 8px 10px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.02);
        page-break-inside: avoid;
    }}

    .month-header {{
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 6px;
        border-bottom: 1px solid #f1f5f9;
        padding-bottom: 4px;
    }}

    .month-header h3 {{
        font-size: 14px;
        font-weight: 700;
        color: #1e293b;
    }}

    .month-subtotal {{
        font-size: 10px;
        font-weight: 600;
        color: var(--muted);
    }}

    .month-table {{
        width: 100%;
        border-collapse: collapse;
        table-layout: fixed;
    }}

    .month-table th {{
        font-size: 10px;
        font-weight: 600;
        color: var(--muted);
        text-align: center;
        padding: 2px 0;
    }}

    .month-table td {{
        height: 24px;
        text-align: center;
        vertical-align: middle;
        font-size: 11px;
        position: relative;
        border-radius: 4px;
    }}

    .day-cell {{
        font-weight: 500;
    }}

    .day-num {{
        position: relative;
        z-index: 2;
    }}

    .shift-badge {{
        position: absolute;
        bottom: 0px;
        right: 1px;
        font-size: 8px;
        line-height: 1;
        z-index: 1;
    }}

    .shift-day {{
        background: var(--day-bg) !important;
        color: var(--day-text) !important;
        font-weight: 700;
        outline: 1px solid var(--day-border);
    }}

    .shift-night {{
        background: var(--night-bg) !important;
        color: var(--night-text) !important;
        font-weight: 700;
        outline: 1px solid var(--night-border);
    }}

    .shift-off {{
        background: var(--off-bg) !important;
        color: var(--off-text) !important;
        font-weight: 700;
        outline: 1px solid var(--off-border);
    }}

    @media print {{
        body {{
            background: #ffffff !important;
            padding: 0 !important;
        }}
        .no-print-bar {{
            display: none !important;
        }}
        .month-card {{
            border: 1px solid #cbd5e1 !important;
            box-shadow: none !important;
        }}
        .grid {{
            gap: 8px !important;
        }}
        .month-table td {{
            height: 22px !important;
        }}
    }}
</style>
</head>
<body>

<div class="no-print-bar">
    <div>
        <strong>{labels['title']} {year}</strong> &mdash; <span>Ready to print or save as PDF</span>
    </div>
    <button class="print-btn" onclick="window.print()">
        <span>🖨️</span> {labels['print_btn']}
    </button>
</div>

<div class="header">
    <div class="header-title">
        <h1>{labels['title']} &mdash; {year}</h1>
    </div>
    <div class="legend">
        <div class="legend-item day">☀️ {labels['day_shift']}: {annual_days}</div>
        <div class="legend-item night">🌙 {labels['night_shift']}: {annual_nights}</div>
        <div class="legend-item off">🏖️ {labels['day_off']}: {annual_offs}</div>
        <div class="legend-item total">📋 {labels['total_shifts']}: {total_worked}</div>
    </div>
</div>

<div class="grid">
    {''.join(months_html)}
</div>

<script>
    // Automatically trigger print dialog when opened
    window.addEventListener('load', function() {{
        setTimeout(function() {{
            window.print();
        }}, 400);
    }});
</script>

</body>
</html>
"""

    out_path = os.path.expanduser(f"~/.config/omarchy/shift-calendar-{year}.html")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(html_content)

    print(f"Generated: {out_path}")
    
    # Launch browser
    browser_bin = "/usr/share/omarchy/bin/omarchy-launch-browser"
    file_url = f"file://{out_path}"
    if os.path.exists(browser_bin):
        subprocess.Popen([browser_bin, file_url])
    else:
        subprocess.Popen(["xdg-open", file_url])

if __name__ == "__main__":
    main()
