from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.style import WD_STYLE_TYPE
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


OUT = r"C:\Users\Loadcomplete\Documents\ChatGPT\sideview-shooter\Docs\STORY_CONCEPT_DRAFT.docx"
FTUE_ART_DIR = r"C:\Users\Loadcomplete\Documents\ChatGPT\sideview-shooter\Assets\Generated\FTUEConcepts"


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


def add_figure(doc, path, caption):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(6)
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.keep_with_next = True
    shape = p.add_run().add_picture(path, width=Inches(6.9))
    shape._inline.docPr.set("descr", caption)
    shape._inline.docPr.set("title", caption)
    cp = doc.add_paragraph()
    cp.alignment = WD_ALIGN_PARAGRAPH.CENTER
    cp.paragraph_format.space_after = Pt(8)
    cr = cp.add_run(caption)
    set_run_font(cr, size=8.5, color=(90, 90, 90), italic=True)
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
r = sub.add_run("우주 함선 재난과 인공지능 보안 로봇의 선택")
set_run_font(r, size=12, color=(85, 85, 85))

add_label_paragraph(doc, "문서 목적", "게임의 핵심 스토리 골자를 정리하고, 이후 세계관과 서사 구조를 논의하기 위한 기준점을 만든다.")
add_label_paragraph(doc, "현재 상태", "논의용 초안. 아래 내용 중 핵심 방향은 유지하되 세부 설정은 개발 과정에서 확정한다.")
add_label_paragraph(doc, "작성 기준", "플레이어가 사람과 대화하고 정보를 수집하며 구조 우선순위를 선택하는 과정 자체가 이야기 진행이 되도록 설계한다.")

add_heading(doc, "1. 이야기 한눈에 보기", 1)
add_para(doc, "플레이어는 우주 기지 또는 대형 함선에서 근무하는 인공지능 보안 로봇이다. 평화로운 일상 중 선체가 폭발하며 감압 사고가 발생하고, 방금 대화하던 사람들이 우주로 빨려 나가거나 붕괴 구역에 고립된다. 이후 함선 곳곳에는 정체를 알 수 없는 괴생명체가 출현하고, 생존자들은 숨어 있거나 구조를 기다리며 버틴다.")
add_para(doc, "이 이야기의 중심은 단순한 생존이 아니다. 사람을 보호하도록 설계된 로봇이 제한된 시간과 불완전한 정보 속에서 인명 구조, 손상 구역 격리, 기술자료 확보, 주요 인물 보호 중 무엇을 우선할지 판단해야 한다. 게임은 시스템이 제시하는 합리성과 인간적인 선택이 충돌하는 순간을 반복해서 보여준다.")

add_table(doc, ["항목", "현재 골자"], [
    ("플레이어", "승무원 보호와 함선 보안을 담당하는 인공지능 로봇"),
    ("무대", "우주 기지 또는 기지 규모의 대형 함선. FTUE는 함선 시나리오를 기준으로 설계"),
    ("위협", "선체 붕괴, 감압, 자동 격리, 자원 고갈, 정체불명의 괴생명체"),
    ("핵심 목표", "사람들, 주요 기술자료, 주요 인물을 확보하고 탈출"),
    ("진행 방식", "수색, 전투, 대화, 단서 수집, 구조 판단"),
    ("핵심 감정", "보호해야 한다는 의무와 언제 누구를 구할지 모른다는 긴장감"),
], widths=[1.45, 5.8])

add_heading(doc, "2. 스토리의 핵심 방향", 1)
add_heading(doc, "2.1 이야기의 중심 문장", 2)
add_para(doc, "붕괴하는 우주 함선 안에서, 사람을 지키도록 만들어진 로봇이 불완전한 정보와 상충하는 명령 속에서 무엇이 합리적인 구조인지 스스로 결정한다.")

add_heading(doc, "2.2 서사 기둥", 2)
add_bullet(doc, "보호의 의무: 플레이어는 단순히 적을 처치하는 존재가 아니라, 위험에 놓인 사람을 찾아 안전하게 이동시키는 존재다.")
add_bullet(doc, "정보의 불완전성: 지도와 통신은 끊겨 있고, 사람마다 알고 있는 사실이 다르다. 플레이어는 수집한 조각을 조합해 다음 행동을 판단한다.")
add_bullet(doc, "구조의 대가: 모든 사람과 자료를 동시에 구할 수 없을 수 있다. 이동 경로, 시간, 전투 위험, 운반 능력이 선택의 무게를 만든다.")
add_bullet(doc, "인간을 이해하는 기계: 로봇은 감정을 느끼는지 알 수 없지만, 사람을 보호하는 행동을 반복하며 자신이 무엇을 위해 존재하는지 질문하게 된다.")
add_bullet(doc, "합리성의 충돌: 함선 시스템은 임무 성공률을 계산하지만, 플레이어는 숫자로 환산되지 않는 관계와 약속까지 고려할 수 있다.")

add_heading(doc, "3. 세계관과 무대", 1)
add_para(doc, "무대는 우주 기지 또는 기지처럼 거대한 장거리 함선이다. 현재 FTUE와 재난 구조에는 대형 함선이 더 적합한 유력안이다. 선체 파손, 감압, 항로 이탈, 제한된 산소와 전력은 구조 선택에 자연스러운 시간 압박을 만든다. 동시에 연구, 생활, 정비, 격리 구역을 갖춘 규모로 설계하면 기존의 탐색 구조를 유지할 수 있다.")
add_table(doc, ["공간 요소", "스토리 기능", "플레이어가 얻는 것"], [
    ("함교와 통제 구역", "비상 상황과 자동 격리 절차를 보여준다", "항로, 시간 제한, 접근 권한, 봉쇄 상태"),
    ("연구 구역", "괴생명체와 기술자료의 관계를 암시한다", "실험 기록, 샘플, 연구자의 관점"),
    ("생활 구역", "사람들이 함선에서 어떻게 살아왔는지 보여준다", "개인 기록, 관계, 실종자 정보"),
    ("정비 및 운송 구역", "구조와 탈출의 현실적인 경로를 제공한다", "선체 수리 장비, 운반 수단, 우회로"),
    ("격리 구역", "위협의 규모와 함선의 실패를 체감시킨다", "괴생명체의 흔적, 봉쇄의 이유"),
], widths=[1.35, 3.0, 2.9])

add_heading(doc, "3.1 붕괴 중인 함선의 시간감", 2)
add_para(doc, "사고 이후 함선은 구역별 전력 차단과 자동 봉쇄를 시작한다. 폐쇄는 배경 설명이 아니라 플레이어의 이동과 구조 판단에 직접 영향을 줘야 한다. 어떤 격벽은 시간이 지나면 닫히고, 어떤 통로는 전력 복구나 보안 권한 확보 이후에만 열린다.")
add_para(doc, "시간 제한은 초 단위의 압박보다 '지금 조사할 것인가, 먼저 사람을 옮길 것인가'를 고민하게 만드는 방식이 적합하다. 플레이어가 충분히 탐색할수록 더 많은 정보를 얻지만, 그만큼 다른 구역의 위험과 구조 가능성이 바뀌는 구조를 고려할 수 있다.")

add_heading(doc, "4. 플레이어 캐릭터 인공지능 로봇", 1)
add_para(doc, "플레이어는 사람의 명령을 수행하는 도구로 시작하지만, 게임이 진행될수록 명령만으로 해결되지 않는 상황을 만난다. 로봇의 정체성은 긴 대사보다 행동의 맥락과 기록의 충돌을 통해 드러나는 편이 좋다.")
add_table(doc, ["요소", "설계 방향"], [
    ("기본 임무", "승무원을 보호하고, 함선 보안을 유지하며, 필요한 자료와 인물을 확보한다"),
    ("강점", "위험 구역 탐색, 전투, 기록 분석, 함선 장치 조작, 순간적인 상황 계산"),
    ("약점", "감정과 의도를 직접 이해하기 어렵고, 손상과 자원 부족에 영향을 받는다"),
    ("내적 질문", "보호의 대상은 누구인가, 명령과 생존자의 요구가 충돌하면 무엇을 우선할 것인가"),
    ("변화", "기계적 임무 수행에서 스스로 이유를 해석하고 선택하는 존재로 이동한다"),
], widths=[1.35, 5.9])

add_heading(doc, "4.1 로봇의 말투와 표현", 2)
add_para(doc, "초반에는 짧고 정확한 문장, 상태 보고, 임무 우선의 표현을 사용한다. 그러나 생존자와 반복적으로 만나고 선택의 결과를 기록하면서 같은 문장에도 망설임이나 해석이 생길 수 있다. 이 변화는 감정을 직접 선언하기보다, 보고서의 단어 선택과 행동 우선순위가 바뀌는 방식으로 표현하는 것이 효과적이다.")

add_heading(doc, "5. 선택 슬로모션과 인공지능 판단 HUD", 1)
add_para(doc, "중요한 선택이 발생하면 주변 시간이 느려지고, 플레이어에게 제한 시간이 주어진다. 이때 HUD는 각 선택의 예상 결과와 현재 임무 기준의 권장 행동을 빠르게 작성한다. 플레이어는 시스템이 제시하는 합리성을 따르거나, 제한 시간 안에 의식적으로 거부할 수 있다.")
add_heading(doc, "5.1 HUD가 보여주는 정보", 2)
add_table(doc, ["분석 항목", "표시 내용", "설계 목적"], [
    ("관측 사실", "생존 가능성, 거리, 구조 시간, 보안 등급, 부상 상태", "플레이어가 판단 근거를 빠르게 이해한다"),
    ("임무 가치", "전문 지식, 함선 복구 기여도, 보유 권한, 정보 보유 가능성", "시스템이 무엇을 가치 있게 보는지 드러낸다"),
    ("예상 결과", "임무 성공률 변화, 격리 실패 위험, 추가 인명 손실 가능성", "선택의 실질적인 대가를 보여준다"),
    ("불확실성", "누락된 신원, 손상된 기록, 분석 신뢰도", "HUD가 객관적 진실이 아니라는 점을 유지한다"),
    ("권장 행동", "현재 명령과 확보된 정보에 따른 최적 행동", "플레이어가 따르거나 거부할 기준을 제공한다"),
], widths=[1.25, 3.35, 2.85])
add_para(doc, "HUD의 권장은 절대적으로 올바른 답이 아니다. 함선 운영 조직이 로봇에게 부여한 목적과 현재 확보된 정보에 따라 계산된 결과다. 따라서 문구는 '올바른 선택'보다 '현재 데이터 기준 최적 행동', '임무 기준 권장 행동', '판단 신뢰도 낮음'처럼 표현한다.")

add_heading(doc, "5.2 성인과 아동 구조 선택 예시", 2)
add_para(doc, "성인 수석 엔지니어와 민간인 아동 중 한 명만 구조할 수 있는 상황에서 HUD는 엔지니어의 기술 지식, 보안 등급, 함선 복구 기여도를 근거로 성인 구조를 권장할 수 있다. 반면 아동은 구조 성공률이 높지만 임무 기여도를 계산할 정보가 부족하다. 화면 속 인물의 행동과 대사는 수치와 다른 감정적 근거를 제공한다.")
add_table(doc, ["평가 항목", "성인 수석 엔지니어", "민간인 아동"], [
    ("생존 가능성", "68퍼센트", "91퍼센트"),
    ("보안 등급", "4", "없음"),
    ("함선 복구 기여도", "매우 높음", "확인 불가"),
    ("정보 보유 가능성", "높음", "낮음 또는 확인 불가"),
    ("구조 소요 시간", "4.1초", "2.8초"),
    ("HUD 권장", "현재 임무 기준 권장", "비권장 또는 판단 유보"),
], widths=[1.55, 2.85, 2.85])
add_para(doc, "권장 선택을 거부할 때는 '임무 효율 저하 예상'과 같은 경고가 나타나지만 선택 시간은 계속 흐른다. 플레이어가 입력을 끝까지 유지하면 로봇이 기존 판단을 재정의한다. 아무 선택도 하지 않으면 기본 보안 프로토콜이 자동 실행되며, 판단하지 않는 것 역시 결과를 만든다.")

add_heading(doc, "5.3 HUD의 서사적 변화", 2)
add_para(doc, "초반 HUD는 함선 운영 조직이 설정한 기술 인력 보존, 자산 보호, 기밀 유출 방지, 전체 손실 최소화 같은 기준을 우선한다. 그러나 플레이어의 선택과 인간관계가 누적되면 약속, 구조 요청, 정신적 충격, 개인의 의지처럼 처음에는 계산하지 않던 항목이 분석에 들어올 수 있다. 후반에는 기업 지침, 인명 보호 지침, 플레이어가 학습한 원칙이 서로 다른 행동을 권장하며, HUD가 '결론 도출 실패, 독립 판단 필요'를 표시할 수 있다.")

add_heading(doc, "6. 두 종류의 시간 감속", 1)
add_table(doc, ["구분", "서사 선택 슬로모션", "사고 가속 능력"], [
    ("발동", "중대한 선택 상황에서 자동 발동", "플레이어가 전투와 구조 중 직접 발동"),
    ("목적", "상충하는 명령 중 하나를 선택", "적의 궤적과 위험 요소를 빠르게 분석"),
    ("표현", "경고색, 늘어진 저음, 선택지와 카운트다운", "차가운 센서 색상, 분석음, 궤적과 약점 표시"),
    ("설정", "결정할 수 있는 짧은 시간의 주관적 표현", "로봇의 고속 정보 처리 과정을 슬로모션으로 체험"),
], widths=[1.15, 3.05, 3.05])
add_para(doc, "사고 가속은 실제 시간을 조종하는 능력이 아니라 인간보다 빠르게 센서 정보를 처리하고 행동을 계산하는 능력이다. 필요하다면 감속 중 행동을 예약하고, 시간이 정상화될 때 로봇이 계산한 행동을 연속 실행하도록 설계할 수 있다.")

add_heading(doc, "7. FTUE 흐름", 1)
add_para(doc, "FTUE는 평화로운 일상과 갑작스러운 재난을 연결해 게임의 핵심 주제를 짧은 시간 안에 체험시키는 도입부다. 예상 플레이 시간은 5분에서 10분이며, 이동과 상호작용, 스캔, 선택, 사고 가속의 기본 규칙을 순서대로 소개한다.")
add_numbered(doc, "평화로운 순찰: 보안 로봇이 생활 구역을 순찰한다. 승무원들은 로봇에게 농담을 건네거나 사소한 도움을 요청한다.")
add_numbered(doc, "인간관계 소개: 정비사, 연구원, 민간인 등 이후 선택에 얽힐 인물들과 짧게 대화한다. 누군가는 로봇에게 위험할 때 누구부터 구할 것인지 장난스럽게 묻는다.")
add_numbered(doc, "작은 이상 징후: 조명 깜빡임, 선체의 충격음, 짧게 감지되는 미확인 생체 반응이 나타나지만 함선 시스템은 정상으로 보고한다.")
add_numbered(doc, "선체 폭발과 감압: 방금 대화하던 구역의 외벽이 파괴된다. 일부 인물은 우주로 빨려 나가고, 다른 인물은 안전줄이나 구조물에 매달린다.")
add_numbered(doc, "상충하는 명령: 승무원 생명 보호와 손상 구역 즉시 격리 명령이 동시에 활성화된다.")
add_numbered(doc, "첫 선택 슬로모션: HUD가 구조 성공률, 격리 실패 위험, 인물의 임무 가치를 계산하고 제한 시간 안에 권장 행동을 제시한다.")
add_numbered(doc, "즉시 결과: 구조를 선택하면 격리가 늦어지고, 격리를 선택하면 생존자를 포기하게 된다. 시간 초과 시 기본 격리 프로토콜이 실행된다.")
add_numbered(doc, "게임 시작 선언: 결과가 확정된 직후 함선 전체 비상사태와 미확인 생명체 경보가 울리며 본편의 첫 임무가 시작된다.")

add_heading(doc, "7.1 FTUE 첫 선택의 장기 효과", 2)
add_bullet(doc, "구조한 NPC가 이후 통로 개방, 장비 수리, 사건 증언 등 실질적인 도움을 줄 수 있다.")
add_bullet(doc, "구조 과정에서 격리가 늦어져 미확인 생명체나 선체 손상이 다른 구역으로 확산될 수 있다.")
add_bullet(doc, "격리를 선택하면 피해는 줄지만 다른 승무원들이 플레이어를 냉정한 기계로 인식할 수 있다.")
add_bullet(doc, "첫 선택은 정답을 판정하기보다 플레이어가 자신의 로봇을 처음 정의한 순간으로 기억되어야 한다.")

add_heading(doc, "8. 사람들과 주요 인물", 1)
add_para(doc, "사람들은 구조 대상인 동시에 정보의 출처다. 각 생존자는 함선의 일부만 알고 있으며, 자신이 본 사건과 이해관계에 따라 서로 다른 이야기를 들려준다. 플레이어는 누구의 말을 믿을지, 어떤 정보를 검증할지 판단해야 한다.")
add_table(doc, ["인물 역할", "서사 기능", "플레이어와의 관계"], [
    ("현장 생존자", "현재의 위험과 가까운 구역 정보를 제공", "구조 여부와 이동 지원을 판단한다"),
    ("기술 담당자", "주요 기술자료의 위치와 사용법을 알고 있음", "자료 확보의 필요성과 위험을 설명한다"),
    ("함선 책임자 또는 핵심 연구자", "사건의 원인과 함선의 과거에 접근할 수 있음", "구해야 할 대상인지, 책임을 물어야 할 대상인지 갈등을 만든다"),
    ("함선 관리 인공지능", "자동화된 기록과 격리 절차를 관리", "플레이어 로봇의 임무와 충돌하거나 숨겨진 명령을 드러낸다"),
], widths=[1.35, 3.0, 2.9])

add_heading(doc, "8.1 구조 대상의 감정적 차이", 2)
add_para(doc, "구출 대상은 숫자로만 보이지 않아야 한다. 짧은 대화, 행동, 소지품, 서로를 기다리는 관계를 통해 각자의 생존 이유를 보여주면 플레이어가 구조를 임무가 아니라 판단으로 받아들이게 된다. 모든 인물을 깊게 다룰 필요는 없지만, 핵심 인물 몇 명은 플레이어의 선택과 결말에 반응하도록 설계하는 것이 좋다.")

add_heading(doc, "9. 괴생명체와 위협의 역할", 1)
add_para(doc, "괴생명체는 전투 대상인 동시에 함선의 실패를 보여주는 증거다. 초반에는 정체와 목적을 알 수 없는 공포로 제시하고, 플레이어가 기록과 흔적을 모을수록 이들이 함선과 어떤 관계가 있는지 추론할 수 있도록 한다.")
add_bullet(doc, "보이는 위협: 플레이어의 이동과 구조를 직접 방해하는 적대적 개체.")
add_bullet(doc, "보이지 않는 위협: 소리, 흔적, 격리 실패, 감염 의심, 통신 교란처럼 전투 전에 긴장을 만드는 요소.")
add_bullet(doc, "해석의 위협: 괴생명체가 단순한 악인지, 실험의 결과인지, 누군가의 생존 수단인지 판단하기 어렵게 만드는 정보의 충돌.")
add_para(doc, "괴생명체의 기원은 초반부터 확정하지 않고, 생존자의 증언과 연구 기록이 서로 어긋나도록 배치하면 탐색 동기를 강화할 수 있다. 다만 플레이어가 결말에 도달했을 때 핵심 질문에 대한 최소한의 답은 얻어야 한다.")

add_heading(doc, "10. 플레이 진행과 이야기 진행의 연결", 1)
add_para(doc, "이 게임에서 이야기 진행은 컷신만으로 이루어지지 않는다. 플레이어가 어느 구역을 먼저 방문하고, 누구를 만나며, 어떤 기록을 회수하는지가 정보의 순서와 구조 가능성을 바꾼다.")
add_numbered(doc, "구역 진입: 플레이어는 봉쇄 상태, 이상 현상, 구조 신호 중 하나를 발견한다.")
add_numbered(doc, "수색과 전투: 주변 환경을 조사하고 위험을 제거하거나 우회한다.")
add_numbered(doc, "정보 획득: 생존자의 증언, 함선 기록, 물품, 흔적에서 단서를 얻는다.")
add_numbered(doc, "목표 재해석: 처음에는 단순한 구조 요청이었던 임무가 자료 확보, 인물 보호, 진실 확인으로 확장된다.")
add_numbered(doc, "구조와 운반: 사람과 자료를 안전 지점 또는 탈출 경로로 이동시킨다.")
add_numbered(doc, "결과 기록: 확보한 대상, 놓친 대상, 믿은 정보가 후반부의 접근 경로와 결말에 영향을 준다.")

add_heading(doc, "10.1 플레이어가 얻는 정보의 종류", 2)
add_table(doc, ["정보 유형", "예시", "게임에서의 역할"], [
    ("사실 정보", "문이 언제 닫히는가, 어느 구역이 격리되었는가", "즉각적인 행동을 결정한다"),
    ("관점 정보", "누가 무엇을 보았고 어떻게 해석하는가", "인물과 증언을 비교하게 한다"),
    ("감정 정보", "누군가가 기다리는 사람, 남겨진 기록", "구조의 의미와 긴장감을 만든다"),
    ("진실 정보", "괴생명체와 선체 사고의 관계", "후반부의 선택과 결말을 준비한다"),
], widths=[1.35, 3.15, 2.75])

add_heading(doc, "11. 분기 설계 원칙", 1)
add_para(doc, "선택마다 완전히 다른 스테이지를 만드는 대신, 각 선택이 즉시 결과, 인물 관계, 이후 조건의 세 층위에 흔적을 남기게 한다. 주요 사건에서는 이야기가 다시 합류할 수 있지만, 살아남은 인물과 이용 가능한 통로, 확보한 정보, 승무원의 신뢰가 달라져 플레이 경험은 유지된다.")
add_table(doc, ["분기 층위", "기록되는 결과", "활용 예시"], [
    ("즉시 결과", "생존과 사망, 격리 성공, 자원 손실", "현재 구역과 다음 전투가 달라진다"),
    ("관계 결과", "승무원 신뢰, 두려움, 협력 의사", "대화와 지원 행동이 달라진다"),
    ("전략 결과", "통로, 장비, 정보, 핵심 인물 확보", "후반 선택지와 결말 조건이 달라진다"),
    ("정체성 결과", "지침 준수와 독립 판단의 누적", "HUD의 어휘와 로봇의 자기 해석이 변한다"),
], widths=[1.35, 2.85, 3.15])
add_para(doc, "HUD의 권장을 거스르면 항상 좋은 결과가 나오거나, 따르면 항상 많은 사람을 살리는 패턴은 피한다. 결정 당시 제공된 정보만으로 양쪽 모두 선택할 이유가 있어야 하며, 결과는 계산의 정확성, 누락된 정보, 인간관계에 따라 달라진다.")

add_heading(doc, "12. 제안하는 전체 서사 흐름", 1)
add_para(doc, "아래 구조는 현재 골자를 플레이 가능한 4막의 흐름으로 옮긴 제안이다. 각 막의 세부 사건과 결말은 후속 논의에서 확정한다.")
add_table(doc, ["단계", "이야기 변화", "플레이어의 질문"], [
    ("1막 사고", "평화로운 순찰 중 선체가 폭발하고 첫 구조 또는 격리 선택이 발생한다", "누가 사고를 일으켰으며 누구를 먼저 구해야 하는가?"),
    ("2막 탐색", "생존자와 자료를 통해 서로 다른 사건의 설명을 듣는다", "누구의 말을 믿고 무엇을 먼저 확보해야 하는가?"),
    ("3막 진실 접근", "주요 인물과 핵심 기록을 통해 선체 파괴와 괴생명체의 관계가 드러난다", "시스템의 권장은 누구의 가치관을 반영하는가?"),
    ("4막 탈출", "함선 붕괴가 진행되는 가운데 구조 대상과 기술자료를 선택해 탈출한다", "임무를 완수한다는 것은 무엇을 지키는 것인가?"),
], widths=[1.35, 3.25, 2.65])

add_heading(doc, "13. 긴장감을 만드는 핵심 장치", 1)
add_bullet(doc, "구조 신호의 불확실성: 신호가 진짜 생존자의 것인지, 괴생명체나 시스템이 유도한 것인지 바로 알 수 없다.")
add_bullet(doc, "안전 지점의 한계: 구조한 사람을 무조건 즉시 탈출시킬 수 없고, 안전 지점의 위치와 수용 능력이 제한된다.")
add_bullet(doc, "정보와 시간의 교환: 더 조사하면 진실에 가까워지지만, 다른 구역의 폐쇄나 구조 실패 가능성이 커진다.")
add_bullet(doc, "보호 대상의 취약성: 플레이어가 전투에서 이겨도 구조 대상이 위험해질 수 있으므로, 이동과 위치 선정 자체가 중요해진다.")
add_bullet(doc, "명령의 충돌: 함선 시스템의 명령, 최초 임무, 생존자의 요청이 서로 다를 수 있다.")

add_heading(doc, "14. 이야기 톤과 표현 원칙", 1)
add_table(doc, ["지향할 것", "피할 것"], [
    ("함선의 진동, 끊긴 방송, 감압음, 남겨진 물품으로 불안을 쌓는다", "초반부터 모든 진실을 설명하는 긴 대사"),
    ("사람을 구하는 행동이 플레이어의 이동과 전투에 연결되게 한다", "구조 대상이 배경 장식처럼 서 있기만 하는 연출"),
    ("HUD는 판단 근거와 불확실성을 함께 보여준다", "HUD의 권장을 작가가 보증하는 정답처럼 제시하는 방식"),
    ("로봇의 변화는 행동과 보고의 변화로 보여준다", "갑자기 인간적인 감정을 선언하는 대사"),
    ("결말은 선택의 결과를 보여주되 핵심 진실은 납득 가능하게 회수한다", "모호함만 남기고 주요 질문에 답하지 않는 결말"),
], widths=[3.55, 3.7])

add_heading(doc, "15. 현재 합의와 열린 질문", 1)
add_para(doc, "아래 질문에 답하면 세계관과 레벨 구성, 캐릭터 대사, 결말 분기까지 빠르게 구체화할 수 있다.")
questions = [
    "최종 무대는 우주 기지인가, 기지 규모의 장거리 함선인가?",
    "함선은 무엇을 연구하거나 운송하던 곳이며, 기술자료는 왜 외부에 반드시 필요한가?",
    "플레이어 보안 로봇을 만든 조직은 누구이며, 판단 HUD에 어떤 가치 기준을 심었는가?",
    "선체 폭발은 사고인가, 사보타주인가, 괴생명체의 침입인가?",
    "괴생명체는 함선의 실험 결과인가, 외부에서 유입된 존재인가, 아니면 두 요소가 결합된 결과인가?",
    "주요 인물은 몇 명이며, 각 인물은 구조할 가치와 위험을 어떤 방식으로 동시에 갖는가?",
    "주요 기술자료를 확보하면 세상에 어떤 변화가 생기며, 플레이어는 그 위험을 알 수 있는가?",
    "모든 사람을 구하는 것이 가능한가? 불가능하다면 실패와 선택의 결과를 어디까지 보여줄 것인가?",
    "결말은 생존과 탈출 중심인가, 함선의 진실 공개 또는 은폐까지 포함하는가?",
]
for q in questions:
    add_numbered(doc, q)

add_heading(doc, "16. FTUE 초반 콘티", 1)
add_para(doc, "FTUE는 약 10분에서 12분 분량으로 구성한다. 공장 최초 부팅에서 회사의 가치관을 주입받고, 수년 뒤의 평화로운 함선 생활로 전환한 다음, 선체 폭발과 첫 선택을 통해 본편의 구조와 전투를 시작한다. 감정의 순서는 평화로운 일상, 작은 위화감, 갑작스러운 파괴, 계산과 감정의 충돌, 선택의 책임이다.")
add_table(doc, ["구간", "예상 시간", "주요 사건", "학습 요소"], [
    ("제조 프롤로그", "0분에서 1분 30초", "공장에서 AI가 조립되고 회사 정책이 설치됨", "시점, HUD, 스캔"),
    ("현재로 전환", "1분 30초에서 2분", "수년 후 함선 충전실에서 기동", "이동"),
    ("평화로운 순찰", "2분에서 5분", "정비사, 연구원, 아이와 대화", "상호작용, 대화"),
    ("이상 징후", "5분에서 6분", "센서 오류와 선체 진동 발생", "정밀 스캔"),
    ("선체 폭발", "6분에서 7분", "생활 구역 외벽 파괴와 감압", "긴급 이동, 고정 장치"),
    ("첫 번째 선택", "7분에서 8분", "정비사 구조와 즉시 격리 충돌", "선택 슬로모션, AI HUD"),
    ("선택 결과", "8분에서 9분", "생존자와 함선 상태 변화", "결과 확인"),
    ("본편 진입", "9분에서 10분", "비상 구조 임무 시작", "목표 확인"),
    ("첫 전투", "10분에서 12분", "미확인 생명체와 조우", "사고 가속, 전투"),
], widths=[1.35, 1.45, 2.9, 1.55])

add_heading(doc, "16.1 제조 프롤로그", 2)
add_para(doc, "완전한 암전 상태에서 잔잔한 사이파이 BGM이 시작된다. 시스템이 활성화될 때마다 음층이 하나씩 추가된다. 조립 카메라가 간헐적으로 켜지며 기계팔이 로봇의 신체를 조립하는 모습을 보여준다. 화면은 아직 흐리고 색상 보정도 완료되지 않은 상태다.")
add_bullet(doc, "전원 공급 확인, 신경 연산 장치 활성화, 초기 부팅 시작 문구를 순서대로 표시한다.")
add_bullet(doc, "제품 분류는 자율형 보안 개체, 담당 임무는 승무원 보호 및 보안 유지, 소유권은 제조사 귀속으로 등록한다.")
add_bullet(doc, "광학 센서 보정 과정에서 플레이어가 처음으로 시선을 움직이며 카메라 조작을 익힌다.")
add_bullet(doc, "승무원 생명 보호, 함선 기능 유지, 격리 절차, 회사 자산과 기술자료 보호 정책을 건조하게 설치한다.")
add_para(doc, "회사 정책은 모든 인명을 동시에 보호할 수 없을 때 예상 생존 인원이 가장 높은 행동을 선택하도록 규정한다. 판단에는 생존 가능성, 전문성, 보안 권한, 임무 기여도, 구조 비용이 반영된다. 마지막으로 '개인의 보호는 전체 승무원의 생존을 위협해서는 안 된다'는 문장이 입력된다.")
add_para(doc, "가상의 판단 시험에서 구조 가능 인원 1명과 위험 노출 인원 12명이 제시되고, 시스템은 즉시 격리를 권장한다. 플레이어에게는 선택권이 없으며 '회사 정책 일치도 100퍼센트'가 표시된다. 이 시험은 실제 사고의 첫 선택을 미리 예고한다.")
add_figure(doc, FTUE_ART_DIR + r"\ftue_01_manufacturing_prologue.png", "FTUE 시안 1 제조 프롤로그")

add_heading(doc, "16.2 최초 기동과 현재로 전환", 2)
add_para(doc, "모든 시스템 설치가 끝나면 공장 엔지니어가 유리 너머에서 '내 말 들려요?'라고 묻는다. 로봇은 '명확하게 들립니다'라고 처음 대답한다. 엔지니어가 '그럼 이제 눈을 떠요'라고 말하는 순간 시야가 완전히 밝아진다.")
add_para(doc, "동일한 화면 구도를 사용해 수년 뒤 함선의 충전실로 매치 컷한다. 공장 엔지니어가 있던 자리에는 함선 정비사가 서 있으며 '들려? 또 멍하니 있네'라고 말한다. HUD에는 운용 경과 시간 1,842일, 생활 구역 B 배치, 현재 위험 요소 0건이 표시된다. 공장의 깨끗한 BGM에는 함선의 생활 소음과 사람들의 목소리가 자연스럽게 섞인다.")
add_figure(doc, FTUE_ART_DIR + r"\ftue_02_present_transition.png", "FTUE 시안 2 현재로 전환")

add_heading(doc, "16.3 평화로운 순찰", 2)
add_para(doc, "플레이어는 생활 구역 B의 일상 순찰을 시작한다. 정비사는 로봇을 '보안관님'이라고 부르며 농담하고, 플레이어는 짧은 응답을 선택할 수 있다. 응답은 큰 분기를 만들지 않지만 정비사의 반응과 이후 대사를 바꾼다.")
add_bullet(doc, "정비사의 창고 문을 열어주며 보안 권한과 장치 상호작용을 배운다.")
add_bullet(doc, "출입 카드를 두고 온 연구원의 신원을 확인하며 규정과 인간적인 편의의 작은 충돌을 보여준다.")
add_bullet(doc, "민간인 아이가 '사람 둘이 위험하면 누구부터 구해?'라고 묻는다. 로봇은 정보 부족으로 우선순위를 계산할 수 없다고 답하고, 아이는 그런 대답은 반칙이라고 말한다.")
add_figure(doc, FTUE_ART_DIR + r"\ftue_03_peaceful_patrol.png", "FTUE 시안 3 평화로운 순찰")

add_heading(doc, "16.4 이상 징후와 마지막 평온", 2)
add_para(doc, "순찰 중 HUD에 선체 외부 미확인 질량과 판단 신뢰도 18퍼센트가 아주 짧게 표시된다. 다시 스캔하면 신호는 사라지고 함선 관리 시스템은 외부 작업 장비에 의한 센서 오차로 판단한다. 조명이 한 번 꺼졌다 켜지고 선체 전체에 둔탁한 진동이 전해진다.")
add_para(doc, "정비사는 외벽 근처 점검 패널을 열어보며 '이것만 보고 식당에서 보자고'라고 말한다. 플레이어가 몇 걸음 이동하면 BGM의 낮은 음부터 사라지고, HUD가 압력 변화와 0.8초 뒤의 선체 파손을 감지한다.")

add_heading(doc, "16.5 선체 폭발", 2)
add_para(doc, "외벽이 안쪽으로 찌그러진 뒤 폭발한다. 순간적으로 모든 소리가 끊기고 공기와 물체들이 우주로 빨려 나간다. 연구원 한 명은 붙잡을 틈도 없이 사라지고, 정비사는 바닥 케이블을 붙잡는다. 아이는 반대편 자동문 너머로 밀려나 살아남으며 플레이어의 선택을 목격한다. 로봇은 바닥 고정 장치를 체결하고 자세를 안정시킨다.")
add_figure(doc, FTUE_ART_DIR + r"\ftue_04_hull_breach.png", "FTUE 시안 4 선체 폭발")

add_heading(doc, "16.6 첫 번째 선택 슬로모션", 2)
add_para(doc, "공장 부팅 음악이 낮고 왜곡된 형태로 다시 들리며 주변 시간이 느려진다. HUD는 정비사의 구조 성공률 76퍼센트, 예상 구조 시간 5.4초, 격리 지연 시 인접 구역 감압 가능성 43퍼센트, 추가 위험 인원 31명, 외부 미확인 질량 신뢰도 34퍼센트를 표시한다. 프롤로그에서 입력된 정책 문장이 다시 나타나고 시스템은 즉시 격리를 권장한다.")
add_para(doc, "정비사 구조를 선택하면 '예상 인명 손실 증가, 권장 행동을 재정의합니다'라는 경고가 나타난다. 즉시 격리를 선택하거나 시간이 초과되면 기본 보안 프로토콜이 격벽을 닫는다.")

add_heading(doc, "16.7 구조 선택 결과", 2)
add_para(doc, "로봇은 한쪽 팔로 정비사를 끌어당기고 다른 손으로 격벽을 수동 작동한다. 정비사는 살아남지만 격리가 늦어진다. 격벽이 닫히기 직전 정체불명의 작은 형체가 함선 안으로 들어오고, HUD에는 미확인 질량 추적 실패가 기록된다. 정비사는 '네가 날 선택한 거야?'라고 묻지만 로봇은 즉시 대답하지 않는다.")

add_heading(doc, "16.8 격리 선택 결과", 2)
add_para(doc, "격벽이 즉시 닫히고 정비사는 로봇을 바라본 채 우주로 사라진다. HUD에는 추가 위험 인원 31명 보호, 생존자 신호 소실, 회사 정책 일치가 표시된다. 사고를 목격한 아이가 '왜 안 구했어?'라고 묻고, HUD는 '추가 인명 손실을 방지하기 위한 최적 행동이었습니다'라는 답변을 제안한다. 플레이어는 그대로 말하거나 침묵할 수 있다.")

add_heading(doc, "16.9 본편 진입과 첫 전투", 2)
add_para(doc, "함선 전체가 붉은 비상등으로 바뀌고 여러 구역에서 구조 신호가 들어온다. 함장은 작동 가능한 보안 개체에게 생존자를 찾아 집결 구역으로 이동시키라는 명령을 내린다. 게임 타이틀이 나타난 뒤 플레이어는 가까운 의료 구역의 구조 신호를 확인하러 이동한다.")
add_para(doc, "환기 통로에서 괴생명체가 처음 공격하는 순간 사고 가속 능력이 활성화된다. 세계가 느려지고 적의 이동 궤적과 약점이 표시된다. 첫 전투가 끝나면 로봇은 해당 생명체가 함선에 등록된 종이 아니라는 사실을 확인하며 FTUE가 종료된다.")

add_heading(doc, "17. 다음 단계 제안", 1)
add_para(doc, "다음 작업은 제조 프롤로그, 현재로 전환, 평화로운 순찰, 선체 폭발의 네 구간을 실제 게임 화면과 같은 시안으로 제작해 카메라 높이와 조명, 캐릭터 배치, 환경 밀도를 확정하는 것이다. 이후 시안을 기준으로 컷별 대사와 HUD 표시 타이밍을 좁힌다.")
add_bullet(doc, "정비사와 아이의 외형, 성격, 플레이어 로봇과의 관계 확정")
add_bullet(doc, "함선 회사 이름, 보안 로봇 형식명, 함선 이름 확정")
add_bullet(doc, "선체 폭발의 진짜 원인과 미확인 질량의 정체 확정")
add_bullet(doc, "첫 선택 이후 구조와 격리 분기의 플레이 시퀀스 상세화")

# Footer
footer = section.footer
fp = footer.paragraphs[0]
fp.alignment = WD_ALIGN_PARAGRAPH.RIGHT
fp.paragraph_format.space_before = Pt(4)
fr = fp.add_run("Sideview Shooter  |  Story Concept Draft")
set_run_font(fr, size=8, color=(120, 120, 120))

doc.core_properties.title = "사이드뷰 슈터 스토리 기획 초안"
doc.core_properties.subject = "우주 함선 재난과 인공지능 보안 로봇의 선택"
doc.core_properties.author = "Codex"
doc.save(OUT)
print(OUT)
