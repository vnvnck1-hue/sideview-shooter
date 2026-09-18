from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.style import WD_STYLE_TYPE
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


OUT = r"C:\Users\Loadcomplete\Documents\ChatGPT\sideview-shooter\Docs\STORY_CONCEPT_DRAFT.docx"


def set_run_font(run, name="Malgun Gothic", size=None, bold=None, color=None, italic=None):
    run.font.name = name
    run._element.get_or_add_rPr().rFonts.set(qn("w:ascii"), name)
    run._element.get_or_add_rPr().rFonts.set(qn("w:hAnsi"), name)
    run._element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), name)
    if size is not None:
        run.font.size = Pt(size)
    if bold is not None:
        run.bold = bold
    if italic is not None:
        run.italic = italic
    if color is not None:
        run.font.color.rgb = RGBColor(*color)


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_border(cell, color="D9D9D9", size="6"):
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    borders = tc_pr.first_child_found_in("w:tcBorders")
    if borders is None:
        borders = OxmlElement("w:tcBorders")
        tc_pr.append(borders)
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        tag = "w:" + edge
        element = borders.find(qn(tag))
        if element is None:
            element = OxmlElement(tag)
            borders.append(element)
        element.set(qn("w:val"), "single")
        element.set(qn("w:sz"), size)
        element.set(qn("w:space"), "0")
        element.set(qn("w:color"), color)


def set_cell_margins(cell, top=100, start=120, bottom=100, end=120):
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for margin, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tc_mar.find(qn("w:" + margin))
        if node is None:
            node = OxmlElement("w:" + margin)
            tc_mar.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def set_repeat_table_header(row):
    tr_pr = row._tr.get_or_add_trPr()
    tbl_header = OxmlElement("w:tblHeader")
    tbl_header.set(qn("w:val"), "true")
    tr_pr.append(tbl_header)


def add_para(doc, text="", style=None, space_after=6, line=1.15, alignment=None):
    p = doc.add_paragraph(style=style)
    if text:
        r = p.add_run(text)
        set_run_font(r, size=10.5, color=(40, 40, 40))
    fmt = p.paragraph_format
    fmt.space_after = Pt(space_after)
    fmt.line_spacing = line
    if alignment is not None:
        p.alignment = alignment
    return p


def add_bullet(doc, text, level=0):
    p = doc.add_paragraph(style="List Bullet" if level == 0 else "List Bullet 2")
    r = p.add_run(text)
    set_run_font(r, size=10.5, color=(40, 40, 40))
    p.paragraph_format.space_after = Pt(3)
    p.paragraph_format.line_spacing = 1.12
    return p


def add_numbered(doc, text):
    p = doc.add_paragraph(style="List Number")
    r = p.add_run(text)
    set_run_font(r, size=10.5, color=(40, 40, 40))
    p.paragraph_format.space_after = Pt(3)
    p.paragraph_format.line_spacing = 1.12
    return p


def add_heading(doc, text, level=1):
    p = doc.add_paragraph(style=f"Heading {level}")
    r = p.add_run(text)
    set_run_font(r, size=15 if level == 1 else 12, bold=True, color=(0, 0, 0))
    p.paragraph_format.keep_with_next = True
    p.paragraph_format.space_before = Pt(15 if level == 1 else 9)
    p.paragraph_format.space_after = Pt(5)
    return p


def add_table(doc, headers, rows, widths=None):
    table = doc.add_table(rows=1, cols=len(headers))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    hdr = table.rows[0]
    set_repeat_table_header(hdr)
    for i, header in enumerate(headers):
        cell = hdr.cells[i]
        if widths:
            cell.width = Inches(widths[i])
        set_cell_shading(cell, "2F5597")
        set_cell_border(cell)
        set_cell_margins(cell)
        cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.LEFT
        p.paragraph_format.space_after = Pt(0)
        r = p.add_run(header)
        set_run_font(r, size=9.5, bold=True, color=(255, 255, 255))
    for ridx, row in enumerate(rows):
        cells = table.add_row().cells
        for i, value in enumerate(row):
            cell = cells[i]
            if widths:
                cell.width = Inches(widths[i])
            set_cell_border(cell)
            set_cell_margins(cell)
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            if ridx % 2 == 1:
                set_cell_shading(cell, "F2F6FB")
            p = cell.paragraphs[0]
            p.paragraph_format.space_after = Pt(0)
            p.paragraph_format.line_spacing = 1.05
            r = p.add_run(str(value))
            set_run_font(r, size=9.5, color=(40, 40, 40))
    doc.add_paragraph().paragraph_format.space_after = Pt(2)
    return table


def add_label_paragraph(doc, label, text):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(5)
    p.paragraph_format.line_spacing = 1.15
    r1 = p.add_run(label + " ")
    set_run_font(r1, size=10.5, bold=True, color=(0, 0, 0))
    r2 = p.add_run(text)
    set_run_font(r2, size=10.5, color=(40, 40, 40))
    return p


doc = Document()
section = doc.sections[0]
section.top_margin = Inches(0.7)
section.bottom_margin = Inches(0.65)
section.left_margin = Inches(0.75)
section.right_margin = Inches(0.75)

styles = doc.styles
normal = styles["Normal"]
normal.font.name = "Malgun Gothic"
normal._element.rPr.rFonts.set(qn("w:ascii"), "Malgun Gothic")
normal._element.rPr.rFonts.set(qn("w:hAnsi"), "Malgun Gothic")
normal._element.rPr.rFonts.set(qn("w:eastAsia"), "Malgun Gothic")
normal.font.size = Pt(10.5)
normal.font.color.rgb = RGBColor(40, 40, 40)

for style_name, size in (("Title", 24), ("Heading 1", 15), ("Heading 2", 12)):
    style = styles[style_name]
    style.font.name = "Malgun Gothic"
    style._element.rPr.rFonts.set(qn("w:ascii"), "Malgun Gothic")
    style._element.rPr.rFonts.set(qn("w:hAnsi"), "Malgun Gothic")
    style._element.rPr.rFonts.set(qn("w:eastAsia"), "Malgun Gothic")
    style.font.size = Pt(size)
    style.font.bold = True
    style.font.color.rgb = RGBColor(0, 0, 0)

for style_name in ("List Bullet", "List Bullet 2", "List Number"):
    style = styles[style_name]
    style.font.name = "Malgun Gothic"
    style._element.rPr.rFonts.set(qn("w:ascii"), "Malgun Gothic")
    style._element.rPr.rFonts.set(qn("w:hAnsi"), "Malgun Gothic")
    style._element.rPr.rFonts.set(qn("w:eastAsia"), "Malgun Gothic")
    style.font.size = Pt(10.5)

# Title page content
title = doc.add_paragraph(style="Title")
title.paragraph_format.space_after = Pt(4)
title.paragraph_format.keep_with_next = True
r = title.add_run("사이드뷰 슈터 스토리 기획 초안")
set_run_font(r, size=24, bold=True, color=(0, 0, 0))

sub = doc.add_paragraph()
sub.paragraph_format.space_after = Pt(18)
r = sub.add_run("폐쇄 시설 구조 작전과 인공지능 로봇의 이야기")
set_run_font(r, size=12, color=(85, 85, 85))

add_label_paragraph(doc, "문서 목적", "게임의 핵심 스토리 골자를 정리하고, 이후 세계관과 서사 구조를 논의하기 위한 기준점을 만든다.")
add_label_paragraph(doc, "현재 상태", "논의용 초안. 아래 내용 중 핵심 방향은 유지하되 세부 설정은 개발 과정에서 확정한다.")
add_label_paragraph(doc, "작성 기준", "플레이어가 정보를 수집하고 사람을 구출하는 과정 자체가 이야기 진행이 되도록 설계한다.")

add_heading(doc, "1. 이야기 한눈에 보기", 1)
add_para(doc, "플레이어는 폐쇄 직전의 연구 시설에 투입된 인공지능 로봇이다. 시설 안에는 정체를 알 수 없는 괴생명체가 퍼져 있고, 일부 사람들은 숨어 있거나 구조를 기다리며 버티고 있다. 로봇은 시설을 탐색하며 생존자와 주변의 흔적에서 정보를 모으고, 사람들과 주요 기술자료 및 주요 인물을 확보한 뒤 시설을 탈출해야 한다.")
add_para(doc, "이 이야기의 중심은 단순한 생존이 아니다. 사람을 보호하도록 설계된 로봇이 제한된 시간과 불완전한 정보 속에서 누구를 먼저 구하고, 무엇을 가지고 나올지 판단해야 한다는 데 있다. 플레이어는 탐색과 전투를 통해 시설의 진실에 접근하고, 구조의 대가와 자신의 존재 이유를 점점 마주하게 된다.")

add_table(doc, ["항목", "현재 골자"], [
    ("플레이어", "사람을 보호하고 임무를 수행하는 인공지능 로봇"),
    ("무대", "폐쇄 직전의 대형 시설. 구역별로 격리와 기능 정지가 진행 중"),
    ("위협", "시설 곳곳을 배회하는 정체불명의 괴생명체"),
    ("핵심 목표", "사람들, 주요 기술자료, 주요 인물을 확보하고 탈출"),
    ("진행 방식", "수색, 전투, 대화, 단서 수집, 구조 판단"),
    ("핵심 감정", "보호해야 한다는 의무와 언제 누구를 구할지 모른다는 긴장감"),
], widths=[1.45, 5.8])

add_heading(doc, "2. 스토리의 핵심 방향", 1)
add_heading(doc, "2.1 이야기의 중심 문장", 2)
add_para(doc, "폐쇄되는 시설 안에서, 사람을 지키도록 만들어진 로봇이 불완전한 정보와 제한된 시간 속에서 구조의 우선순위를 결정한다.")

add_heading(doc, "2.2 서사 기둥", 2)
add_bullet(doc, "보호의 의무: 플레이어는 단순히 적을 처치하는 존재가 아니라, 위험에 놓인 사람을 찾아 안전하게 이동시키는 존재다.")
add_bullet(doc, "정보의 불완전성: 지도와 통신은 끊겨 있고, 사람마다 알고 있는 사실이 다르다. 플레이어는 수집한 조각을 조합해 다음 행동을 판단한다.")
add_bullet(doc, "구조의 대가: 모든 사람과 자료를 동시에 구할 수 없을 수 있다. 이동 경로, 시간, 전투 위험, 운반 능력이 선택의 무게를 만든다.")
add_bullet(doc, "인간을 이해하는 기계: 로봇은 감정을 느끼는지 알 수 없지만, 사람을 보호하는 행동을 반복하며 자신이 무엇을 위해 존재하는지 질문하게 된다.")

add_heading(doc, "3. 세계관과 무대", 1)
add_para(doc, "시설은 연구, 제조, 보관 또는 통제 기능이 결합된 폐쇄형 공간으로 설정할 수 있다. 중요한 점은 시설이 단순한 배경이 아니라, 이야기 정보를 저장하고 전달하는 거대한 증거물처럼 작동해야 한다는 것이다.")
add_table(doc, ["공간 요소", "스토리 기능", "플레이어가 얻는 것"], [
    ("통제 구역", "시설의 비상 상황과 폐쇄 절차를 보여준다", "현재 시간 제한, 접근 권한, 봉쇄 상태"),
    ("연구 구역", "괴생명체와 기술자료의 관계를 암시한다", "실험 기록, 샘플, 연구자의 관점"),
    ("생활 구역", "사람들이 시설에서 어떻게 살아왔는지 보여준다", "개인 기록, 관계, 실종자 정보"),
    ("정비 및 운송 구역", "구조와 탈출의 현실적인 경로를 제공한다", "장비, 운반 수단, 우회로"),
    ("격리 구역", "위협의 규모와 시설의 실패를 체감시킨다", "괴생명체의 흔적, 봉쇄의 이유"),
], widths=[1.35, 3.0, 2.9])

add_heading(doc, "3.1 폐쇄 직전이라는 시간감", 2)
add_para(doc, "시설은 이미 정상 운영을 멈췄고, 구역별 전력 차단과 자동 봉쇄가 이어진다. 폐쇄는 배경 설명이 아니라 플레이어의 이동과 구조 판단에 직접 영향을 줘야 한다. 어떤 문은 시간이 지나면 닫히고, 어떤 통로는 전력 복구나 자료 확보 이후에만 열린다.")
add_para(doc, "시간 제한은 초 단위의 압박보다 '지금 조사할 것인가, 먼저 사람을 옮길 것인가'를 고민하게 만드는 방식이 적합하다. 플레이어가 충분히 탐색할수록 더 많은 정보를 얻지만, 그만큼 다른 구역의 위험과 구조 가능성이 바뀌는 구조를 고려할 수 있다.")

add_heading(doc, "4. 플레이어 캐릭터 인공지능 로봇", 1)
add_para(doc, "플레이어는 사람의 명령을 수행하는 도구로 시작하지만, 게임이 진행될수록 명령만으로 해결되지 않는 상황을 만난다. 로봇의 정체성은 긴 대사보다 행동의 맥락과 기록의 충돌을 통해 드러나는 편이 좋다.")
add_table(doc, ["요소", "설계 방향"], [
    ("기본 임무", "사람을 보호하고, 임무에 필요한 자료와 인물을 확보한다"),
    ("강점", "위험한 구역 탐색, 전투, 기록 분석, 시설 장치 조작"),
    ("약점", "감정과 의도를 직접 이해하기 어렵고, 손상과 자원 부족에 영향을 받는다"),
    ("내적 질문", "보호의 대상은 누구인가, 명령과 생존자의 요구가 충돌하면 무엇을 우선할 것인가"),
    ("변화", "기계적 임무 수행에서 스스로 이유를 해석하고 선택하는 존재로 이동한다"),
], widths=[1.35, 5.9])

add_heading(doc, "4.1 로봇의 말투와 표현", 2)
add_para(doc, "초반에는 짧고 정확한 문장, 상태 보고, 임무 우선의 표현을 사용한다. 그러나 생존자와 반복적으로 만나고 선택의 결과를 기록하면서 같은 문장에도 망설임이나 해석이 생길 수 있다. 이 변화는 감정을 직접 선언하기보다, 보고서의 단어 선택과 행동 우선순위가 바뀌는 방식으로 표현하는 것이 효과적이다.")

add_heading(doc, "5. 사람들과 주요 인물", 1)
add_para(doc, "사람들은 구조 대상인 동시에 정보의 출처다. 각 생존자는 시설의 일부만 알고 있으며, 자신이 본 사건과 이해관계에 따라 서로 다른 이야기를 들려준다. 플레이어는 누구의 말을 믿을지, 어떤 정보를 검증할지 판단해야 한다.")
add_table(doc, ["인물 역할", "서사 기능", "플레이어와의 관계"], [
    ("현장 생존자", "현재의 위험과 가까운 구역 정보를 제공", "구조 여부와 이동 지원을 판단한다"),
    ("기술 담당자", "주요 기술자료의 위치와 사용법을 알고 있음", "자료 확보의 필요성과 위험을 설명한다"),
    ("시설 책임자 또는 핵심 연구자", "사건의 원인과 시설의 과거에 접근할 수 있음", "구해야 할 대상인지, 책임을 물어야 할 대상인지 갈등을 만든다"),
    ("시설 관리 인공지능", "자동화된 기록과 폐쇄 절차를 관리", "플레이어 로봇의 임무와 충돌하거나 숨겨진 명령을 드러낸다"),
], widths=[1.35, 3.0, 2.9])

add_heading(doc, "5.1 구조 대상의 감정적 차이", 2)
add_para(doc, "구출 대상은 숫자로만 보이지 않아야 한다. 짧은 대화, 행동, 소지품, 서로를 기다리는 관계를 통해 각자의 생존 이유를 보여주면 플레이어가 구조를 임무가 아니라 판단으로 받아들이게 된다. 모든 인물을 깊게 다룰 필요는 없지만, 핵심 인물 몇 명은 플레이어의 선택과 결말에 반응하도록 설계하는 것이 좋다.")

add_heading(doc, "6. 괴생명체와 위협의 역할", 1)
add_para(doc, "괴생명체는 전투 대상인 동시에 시설의 실패를 보여주는 증거다. 초반에는 정체와 목적을 알 수 없는 공포로 제시하고, 플레이어가 기록과 흔적을 모을수록 이들이 시설과 어떤 관계가 있는지 추론할 수 있도록 한다.")
add_bullet(doc, "보이는 위협: 플레이어의 이동과 구조를 직접 방해하는 적대적 개체.")
add_bullet(doc, "보이지 않는 위협: 소리, 흔적, 격리 실패, 감염 의심, 통신 교란처럼 전투 전에 긴장을 만드는 요소.")
add_bullet(doc, "해석의 위협: 괴생명체가 단순한 악인지, 실험의 결과인지, 누군가의 생존 수단인지 판단하기 어렵게 만드는 정보의 충돌.")
add_para(doc, "괴생명체의 기원은 초반부터 확정하지 않고, 생존자의 증언과 연구 기록이 서로 어긋나도록 배치하면 탐색 동기를 강화할 수 있다. 다만 플레이어가 결말에 도달했을 때 핵심 질문에 대한 최소한의 답은 얻어야 한다.")

add_heading(doc, "7. 플레이 진행과 이야기 진행의 연결", 1)
add_para(doc, "이 게임에서 이야기 진행은 컷신만으로 이루어지지 않는다. 플레이어가 어느 구역을 먼저 방문하고, 누구를 만나며, 어떤 기록을 회수하는지가 정보의 순서와 구조 가능성을 바꾼다.")
add_numbered(doc, "구역 진입: 플레이어는 봉쇄 상태, 이상 현상, 구조 신호 중 하나를 발견한다.")
add_numbered(doc, "수색과 전투: 주변 환경을 조사하고 위험을 제거하거나 우회한다.")
add_numbered(doc, "정보 획득: 생존자의 증언, 시설 기록, 물품, 흔적에서 단서를 얻는다.")
add_numbered(doc, "목표 재해석: 처음에는 단순한 구조 요청이었던 임무가 자료 확보, 인물 보호, 진실 확인으로 확장된다.")
add_numbered(doc, "구조와 운반: 사람과 자료를 안전 지점 또는 탈출 경로로 이동시킨다.")
add_numbered(doc, "결과 기록: 확보한 대상, 놓친 대상, 믿은 정보가 후반부의 접근 경로와 결말에 영향을 준다.")

add_heading(doc, "7.1 플레이어가 얻는 정보의 종류", 2)
add_table(doc, ["정보 유형", "예시", "게임에서의 역할"], [
    ("사실 정보", "문이 언제 닫히는가, 어느 구역이 격리되었는가", "즉각적인 행동을 결정한다"),
    ("관점 정보", "누가 무엇을 보았고 어떻게 해석하는가", "인물과 증언을 비교하게 한다"),
    ("감정 정보", "누군가가 기다리는 사람, 남겨진 기록", "구조의 의미와 긴장감을 만든다"),
    ("진실 정보", "괴생명체와 시설 사고의 관계", "후반부의 선택과 결말을 준비한다"),
], widths=[1.35, 3.15, 2.75])

add_heading(doc, "8. 제안하는 전체 서사 흐름", 1)
add_para(doc, "아래 구조는 현재 골자를 플레이 가능한 4막의 흐름으로 옮긴 제안이다. 각 막의 세부 사건과 결말은 후속 논의에서 확정한다.")
add_table(doc, ["단계", "이야기 변화", "플레이어의 질문"], [
    ("1막 진입", "로봇이 시설에 들어오고 첫 구조 신호와 괴생명체를 마주한다", "누가 살아 있고, 시설은 왜 닫히는가?"),
    ("2막 탐색", "생존자와 자료를 통해 서로 다른 사건의 설명을 듣는다", "누구의 말을 믿어야 하며, 무엇을 먼저 확보해야 하는가?"),
    ("3막 진실 접근", "주요 인물과 핵심 기록을 통해 시설의 실패와 기술의 목적이 드러난다", "구해야 할 사람과 숨겨야 할 정보는 무엇인가?"),
    ("4막 탈출", "폐쇄가 완료되는 가운데 구조 대상과 기술자료를 선택해 탈출한다", "임무를 완수한다는 것은 무엇을 가지고 나오는 것인가?"),
], widths=[1.35, 3.25, 2.65])

add_heading(doc, "9. 긴장감을 만드는 핵심 장치", 1)
add_bullet(doc, "구조 신호의 불확실성: 신호가 진짜 생존자의 것인지, 괴생명체나 시스템이 유도한 것인지 바로 알 수 없다.")
add_bullet(doc, "안전 지점의 한계: 구조한 사람을 무조건 즉시 탈출시킬 수 없고, 안전 지점의 위치와 수용 능력이 제한된다.")
add_bullet(doc, "정보와 시간의 교환: 더 조사하면 진실에 가까워지지만, 다른 구역의 폐쇄나 구조 실패 가능성이 커진다.")
add_bullet(doc, "보호 대상의 취약성: 플레이어가 전투에서 이겨도 구조 대상이 위험해질 수 있으므로, 이동과 위치 선정 자체가 중요해진다.")
add_bullet(doc, "명령의 충돌: 시설 시스템의 명령, 최초 임무, 생존자의 요청이 서로 다를 수 있다.")

add_heading(doc, "10. 이야기 톤과 표현 원칙", 1)
add_table(doc, ["지향할 것", "피할 것"], [
    ("조용한 시설의 소리, 끊긴 방송, 남겨진 물품으로 불안을 쌓는다", "초반부터 모든 진실을 설명하는 긴 대사"),
    ("사람을 구하는 행동이 플레이어의 이동과 전투에 연결되게 한다", "구조 대상이 배경 장식처럼 서 있기만 하는 연출"),
    ("기록과 증언이 부분적으로 맞고 부분적으로 어긋나게 한다", "어떤 정보가 중요한지 UI가 모두 알려주는 방식"),
    ("로봇의 변화는 행동과 보고의 변화로 보여준다", "갑자기 인간적인 감정을 선언하는 대사"),
    ("결말은 선택의 결과를 보여주되 핵심 진실은 납득 가능하게 회수한다", "모호함만 남기고 주요 질문에 답하지 않는 결말"),
], widths=[3.55, 3.7])

add_heading(doc, "11. 후속 논의를 위한 핵심 질문", 1)
add_para(doc, "아래 질문에 답하면 세계관과 레벨 구성, 캐릭터 대사, 결말 분기까지 빠르게 구체화할 수 있다.")
questions = [
    "시설은 무엇을 연구하거나 생산하던 곳인가? 기술자료는 왜 외부에 반드시 필요한가?",
    "플레이어 로봇은 누가 어떤 목적으로 보냈으며, 최초 명령은 정확히 무엇인가?",
    "괴생명체는 시설의 실험 결과인가, 외부에서 유입된 존재인가, 아니면 두 요소가 결합된 결과인가?",
    "시설의 폐쇄는 사고 대응인가, 외부 유출을 막기 위한 의도적인 결정인가?",
    "주요 인물은 몇 명이며, 각 인물은 구조할 가치와 위험을 어떤 방식으로 동시에 갖는가?",
    "주요 기술자료를 확보하면 세상에 어떤 변화가 생기며, 플레이어는 그 위험을 알 수 있는가?",
    "모든 사람을 구하는 것이 가능한가? 불가능하다면 실패와 선택의 결과를 어디까지 보여줄 것인가?",
    "결말은 생존과 탈출 중심인가, 시설의 진실 공개 또는 은폐까지 포함하는가?",
]
for q in questions:
    add_numbered(doc, q)

add_heading(doc, "12. 다음 단계 제안", 1)
add_para(doc, "다음 논의에서는 아래 순서로 설정을 좁히는 것이 좋다. 먼저 시설의 정체와 괴생명체의 기원을 정하면, 구조 대상과 기술자료의 가치가 자연스럽게 결정된다. 그 다음 플레이어 로봇의 최초 명령과 주요 인물 3명 내외를 정하고, 마지막으로 4막의 핵심 사건과 결말 분기를 설계한다.")
add_bullet(doc, "1차 결정: 시설의 목적, 폐쇄 원인, 괴생명체의 정체 범위")
add_bullet(doc, "2차 결정: 로봇의 임무와 한계, 주요 인물, 구조 우선순위")
add_bullet(doc, "3차 결정: 구역별 단서, 주요 사건, 결말 조건")

# Footer
footer = section.footer
fp = footer.paragraphs[0]
fp.alignment = WD_ALIGN_PARAGRAPH.RIGHT
fp.paragraph_format.space_before = Pt(4)
fr = fp.add_run("Sideview Shooter  |  Story Concept Draft")
set_run_font(fr, size=8, color=(120, 120, 120))

doc.core_properties.title = "사이드뷰 슈터 스토리 기획 초안"
doc.core_properties.subject = "폐쇄 시설 구조 작전과 인공지능 로봇의 이야기"
doc.core_properties.author = "Codex"
doc.save(OUT)
print(OUT)
