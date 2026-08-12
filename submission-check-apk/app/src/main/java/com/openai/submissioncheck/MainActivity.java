package com.openai.submissioncheck;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class MainActivity extends Activity {
    private static final int TODO = 0;
    private static final int DOING = 1;
    private static final int DONE = 2;

    private static final int NAVY = Color.rgb(16, 24, 40);
    private static final int BLUE = Color.rgb(23, 92, 211);
    private static final int BLUE_SOFT = Color.rgb(239, 248, 255);
    private static final int BG = Color.rgb(247, 248, 250);
    private static final int TEXT = Color.rgb(16, 24, 40);
    private static final int MUTED = Color.rgb(102, 112, 133);
    private static final int LINE = Color.rgb(234, 236, 240);
    private static final int GREEN = Color.rgb(6, 118, 71);
    private static final int GREEN_SOFT = Color.rgb(236, 253, 243);
    private static final int ORANGE = Color.rgb(181, 71, 8);
    private static final int ORANGE_SOFT = Color.rgb(255, 250, 235);
    private static final int GRAY_SOFT = Color.rgb(242, 244, 247);

    private SharedPreferences prefs;
    private LinearLayout content;
    private TextView headerCount;
    private TextView headerPercent;
    private TextView headerDetail;
    private ProgressBar progressBar;
    private TextView tabCheck;
    private TextView tabContacts;
    private boolean showingContacts = false;

    private final List<CheckItem> checks = new ArrayList<>();
    private final List<Contact> contacts = new ArrayList<>();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(NAVY);
        getWindow().setNavigationBarColor(Color.WHITE);
        prefs = getSharedPreferences("submission_check_v2", MODE_PRIVATE);
        seedData();
        buildShell();
        showChecklist();
    }

    private void seedData() {
        checks.add(new CheckItem("1-1", "대출금", "대출금 최종사용처 정리", "양식 대출금 최종사용처 정리 · 초안 작성 후 요청 예정", TODO));
        checks.add(new CheckItem("1-2", "대출금", "대출금 입금 계좌 정보 및 날짜", "명시된 대출금 입금 계좌 정보 작성 완료", DONE));
        checks.add(new CheckItem("2-1", "신용카드", "신용카드 이용내역 정리", "초안 작성 후 요청 예정", TODO));
        checks.add(new CheckItem("2-2", "신용카드", "카드사별 이용내역 발급", "2025.08.01~2026.07.31 · 현대/롯데/신한/국민/삼성 · 엑셀 발급", DONE));
        checks.add(new CheckItem("3-1", "활동성계좌", "50만원 이상 입출금 정리", "2025.06.01~2026.07.31 · 50만원 이상 거래 정리", TODO));
        checks.add(new CheckItem("3-2", "활동성계좌", "제출 계좌 거래내역 준비", "은행·증권계좌·카카오페이 거래내역 확인", DOING));
        checks.add(new CheckItem("4-1", "주식 투자내역 소명", "출금 사용처 정리", "초안 작성 후 요청 예정", TODO));
        checks.add(new CheckItem("4-2", "주식 투자내역 소명", "투자내역 정리", "초안 작성 후 요청 예정", TODO));
        checks.add(new CheckItem("4-3", "주식 투자내역 소명", "증권사 거래내역 발급", "2025.01.01~2026.07.31 · 현금 입출금 및 자산 매매 내역 모두 포함", TODO));
        checks.add(new CheckItem("4-4", "주식 투자내역 소명", "잔고증명서", "현재 기준 잔고증명서 발급", TODO));
        checks.add(new CheckItem("4-5", "주식 투자내역 소명", "투자 손실 상세 진술서", "투자 시작부터 개인회생 신청 시점까지 손실 과정 진술", TODO));
        checks.add(new CheckItem("4-6", "주식 투자내역 소명", "기간별 수익률 조회", "기간별 수익률 / 계좌 수익률 / 투자손익 등 조회", TODO));

        String cardMemo = "신용카드 이용내역(2025.08.01~2026.07.31)\n엑셀 파일로 발급";
        contacts.add(new Contact("카드사", "현대카드", "1577-6000", cardMemo));
        contacts.add(new Contact("카드사", "롯데카드", "1588-8100", cardMemo));
        contacts.add(new Contact("카드사", "신한카드", "1544-7000", cardMemo));
        contacts.add(new Contact("카드사", "KB국민카드", "1588-1688", cardMemo));
        contacts.add(new Contact("카드사", "삼성카드", "1588-8700", cardMemo));

        contacts.add(new Contact("은행", "케이뱅크", "1522-1000", bankMemo("1001141***04")));
        contacts.add(new Contact("은행", "토스뱅크", "1661-7654", bankMemo("1000004***54")));
        contacts.add(new Contact("은행", "하나은행", "1588-1111", bankMemo("255910314***07\n458910016***05")));

        contacts.add(new Contact("증권사", "KB증권", "1588-6611", securityMemo("386745***01\n386744***01")));
        contacts.add(new Contact("증권사", "NH투자증권", "1544-0000", securityMemo("203019***17")));
        contacts.add(new Contact("증권사", "메리츠증권", "1588-3400", securityMemo("30594***01")));
        contacts.add(new Contact("증권사", "신한투자증권", "1588-0365", securityMemo("270124***09")));
        contacts.add(new Contact("증권사", "카카오페이증권", "1600-8515", securityMemo("020037***39")));
        contacts.add(new Contact("증권사", "토스증권", "1599-7987", securityMemo("127010***35")));
        contacts.add(new Contact("증권사", "하나증권", "1588-3111", securityMemo("393456***10\n402347***10\n376063***10")));
        contacts.add(new Contact("증권사", "한국투자증권", "1544-5000", securityMemo("47244***01")));

        contacts.add(new Contact("간편결제", "카카오페이", "1644-7405", "카카오페이 거래내역\n제출용 거래내역 발급/확인"));
    }

    private String bankMemo(String accounts) {
        return "계좌\n" + accounts + "\n\n활동성계좌 입출금내역(2025.06.01~2026.07.31)\n50만원 이상 입출금 정리";
    }

    private String securityMemo(String accounts) {
        return "계좌\n" + accounts + "\n\n주식 증권사 거래내역(2025.01.01~2026.07.31)\n현금 입출금 및 자산 매매 내역 모두 포함\n잔고증명서(현재 기준)\n기간별수익률 조회";
    }

    private void buildShell() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(BG);

        root.addView(buildHeader());

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setClipToPadding(false);
        scroll.setVerticalScrollBarEnabled(false);
        content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(dp(16), dp(16), dp(16), dp(28));
        scroll.addView(content);
        root.addView(scroll, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1));

        root.addView(buildBottomNav());
        setContentView(root);
    }

    private View buildHeader() {
        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.VERTICAL);
        header.setPadding(dp(20), dp(18), dp(20), dp(22));
        GradientDrawable hbg = new GradientDrawable();
        hbg.setColor(NAVY);
        hbg.setCornerRadii(new float[]{0,0,0,0,dp(28),dp(28),dp(28),dp(28)});
        header.setBackground(hbg);

        TextView eyebrow = text("개인회생 제출자료", 12, Color.rgb(208, 213, 221), Typeface.BOLD);
        header.addView(eyebrow);

        TextView title = text("서류 준비 현황", 23, Color.WHITE, Typeface.BOLD);
        LinearLayout.LayoutParams titleLp = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        titleLp.setMargins(0, dp(4), 0, dp(14));
        header.addView(title, titleLp);

        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);

        headerCount = text("0 / 0 완료", 30, Color.WHITE, Typeface.BOLD);
        row.addView(headerCount, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1));

        headerPercent = text("0%", 15, Color.WHITE, Typeface.BOLD);
        headerPercent.setGravity(Gravity.CENTER);
        headerPercent.setPadding(dp(13), dp(7), dp(13), dp(7));
        headerPercent.setBackground(round(Color.rgb(52, 64, 84), 999));
        row.addView(headerPercent);
        header.addView(row);

        progressBar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        progressBar.setMax(100);
        progressBar.setProgressTintList(ColorStateList.valueOf(Color.WHITE));
        progressBar.setProgressBackgroundTintList(ColorStateList.valueOf(Color.rgb(71, 84, 103)));
        LinearLayout.LayoutParams pLp = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(8));
        pLp.setMargins(0, dp(14), 0, dp(10));
        header.addView(progressBar, pLp);

        headerDetail = text("완료 0 · 진행중 0 · 남음 0", 12, Color.rgb(208, 213, 221), Typeface.NORMAL);
        header.addView(headerDetail);
        return header;
    }

    private View buildBottomNav() {
        LinearLayout bar = new LinearLayout(this);
        bar.setOrientation(LinearLayout.HORIZONTAL);
        bar.setGravity(Gravity.CENTER);
        bar.setPadding(dp(10), dp(9), dp(10), dp(10));
        bar.setBackgroundColor(Color.WHITE);
        bar.setElevation(dp(10));

        tabCheck = navItem("✓  서류 체크", true);
        tabCheck.setOnClickListener(v -> showChecklist());
        bar.addView(tabCheck, new LinearLayout.LayoutParams(0, dp(48), 1));

        tabContacts = navItem("☎  고객센터", false);
        tabContacts.setOnClickListener(v -> showContacts(""));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, dp(48), 1);
        lp.setMargins(dp(8), 0, 0, 0);
        bar.addView(tabContacts, lp);
        return bar;
    }

    private TextView navItem(String label, boolean active) {
        TextView v = text(label, 14, active ? NAVY : MUTED, Typeface.BOLD);
        v.setGravity(Gravity.CENTER);
        v.setBackground(round(active ? GRAY_SOFT : Color.TRANSPARENT, 14));
        return v;
    }

    private void updateHeader() {
        int done = 0;
        int doing = 0;
        for (CheckItem item : checks) {
            int state = getState(item);
            if (state == DONE) done++;
            if (state == DOING) doing++;
        }
        int total = checks.size();
        int todo = total - done - doing;
        int pct = Math.round(done * 100f / total);
        headerCount.setText(done + " / " + total + " 완료");
        headerPercent.setText(pct + "%");
        headerDetail.setText("완료 " + done + " · 진행중 " + doing + " · 남음 " + todo);
        progressBar.setProgress(pct);

        tabCheck.setTextColor(showingContacts ? MUTED : NAVY);
        tabCheck.setBackground(round(showingContacts ? Color.TRANSPARENT : GRAY_SOFT, 14));
        tabContacts.setTextColor(showingContacts ? NAVY : MUTED);
        tabContacts.setBackground(round(showingContacts ? GRAY_SOFT : Color.TRANSPARENT, 14));
    }

    private void showChecklist() {
        showingContacts = false;
        content.removeAllViews();
        updateHeader();

        LinearLayout overview = card(18);
        TextView overTitle = text("한눈에 보기", 16, TEXT, Typeface.BOLD);
        overview.addView(overTitle);
        TextView overBody = text("항목 오른쪽의 상태 버튼을 누르면\n미완료 → 진행중 → 완료 순서로 변경됩니다.", 13, MUTED, Typeface.NORMAL);
        overBody.setLineSpacing(0, 1.15f);
        LinearLayout.LayoutParams oLp = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        oLp.setMargins(0, dp(6), 0, 0);
        overview.addView(overBody, oLp);
        content.addView(overview);

        String lastGroup = "";
        for (CheckItem item : checks) {
            if (!item.group.equals(lastGroup)) {
                addSection(item.group, groupCount(item.group));
                lastGroup = item.group;
            }
            addCheckCard(item);
        }
    }

    private String groupCount(String group) {
        int total = 0, done = 0;
        for (CheckItem item : checks) {
            if (item.group.equals(group)) {
                total++;
                if (getState(item) == DONE) done++;
            }
        }
        return done + "/" + total;
    }

    private void addCheckCard(CheckItem item) {
        LinearLayout card = card(18);

        LinearLayout top = new LinearLayout(this);
        top.setOrientation(LinearLayout.HORIZONTAL);
        top.setGravity(Gravity.TOP);

        TextView num = text(item.id, 12, BLUE, Typeface.BOLD);
        num.setGravity(Gravity.CENTER);
        num.setPadding(dp(9), dp(5), dp(9), dp(5));
        num.setBackground(round(BLUE_SOFT, 999));
        top.addView(num);

        LinearLayout titles = new LinearLayout(this);
        titles.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams titlesLp = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1);
        titlesLp.setMargins(dp(10), 0, dp(8), 0);
        top.addView(titles, titlesLp);

        TextView title = text(item.title, 15, TEXT, Typeface.BOLD);
        titles.addView(title);

        TextView desc = text(item.desc, 12, MUTED, Typeface.NORMAL);
        desc.setLineSpacing(0, 1.18f);
        LinearLayout.LayoutParams dLp = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        dLp.setMargins(0, dp(5), 0, 0);
        titles.addView(desc, dLp);

        int state = getState(item);
        TextView chip = stateChip(state);
        chip.setOnClickListener(v -> {
            int next = (getState(item) + 1) % 3;
            prefs.edit().putInt("state_" + item.id, next).apply();
            showChecklist();
        });
        top.addView(chip);
        card.addView(top);
        content.addView(card);
    }

    private TextView stateChip(int state) {
        String label;
        int fg;
        int bg;
        if (state == DONE) {
            label = "완료";
            fg = GREEN;
            bg = GREEN_SOFT;
        } else if (state == DOING) {
            label = "진행중";
            fg = ORANGE;
            bg = ORANGE_SOFT;
        } else {
            label = "미완료";
            fg = MUTED;
            bg = GRAY_SOFT;
        }
        TextView chip = text(label, 12, fg, Typeface.BOLD);
        chip.setGravity(Gravity.CENTER);
        chip.setPadding(dp(10), dp(6), dp(10), dp(6));
        chip.setBackground(round(bg, 999));
        return chip;
    }

    private void showContacts(String query) {
        showingContacts = true;
        content.removeAllViews();
        updateHeader();

        TextView lead = text("필요한 기관을 바로 찾고 전화하세요", 18, TEXT, Typeface.BOLD);
        content.addView(lead);
        TextView sub = text("작성해둔 계좌와 발급할 자료를 기본 메모로 넣었습니다.", 13, MUTED, Typeface.NORMAL);
        LinearLayout.LayoutParams subLp = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        subLp.setMargins(0, dp(5), 0, dp(12));
        content.addView(sub, subLp);

        EditText search = new EditText(this);
        search.setHint("기관명·전화번호·계좌번호 검색");
        search.setSingleLine(true);
        search.setTextSize(14);
        search.setTextColor(TEXT);
        search.setHintTextColor(Color.rgb(152, 162, 179));
        search.setPadding(dp(14), 0, dp(14), 0);
        search.setBackground(stroke(Color.WHITE, LINE, 16, 1));
        search.setText(query);
        LinearLayout.LayoutParams sLp = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(50));
        sLp.setMargins(0, 0, 0, dp(8));
        content.addView(search, sLp);
        search.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            @Override public void onTextChanged(CharSequence s, int start, int before, int count) {}
            @Override public void afterTextChanged(Editable s) {
                if (!s.toString().equals(query)) showContacts(s.toString());
            }
        });
        search.requestFocus();
        search.clearFocus();

        String normalized = query == null ? "" : query.trim().toLowerCase(Locale.KOREA);
        String lastGroup = "";
        int shown = 0;
        for (Contact c : contacts) {
            String hay = (c.group + " " + c.name + " " + c.phone + " " + c.defaultMemo).toLowerCase(Locale.KOREA);
            if (!normalized.isEmpty() && !hay.contains(normalized)) continue;
            if (!c.group.equals(lastGroup)) {
                addSection(c.group, "");
                lastGroup = c.group;
            }
            addContactCard(c);
            shown++;
        }
        if (shown == 0) {
            TextView empty = text("검색 결과가 없습니다.", 14, MUTED, Typeface.NORMAL);
            empty.setGravity(Gravity.CENTER);
            empty.setPadding(0, dp(40), 0, dp(40));
            content.addView(empty);
        }
    }

    private void addContactCard(Contact c) {
        LinearLayout card = card(20);

        LinearLayout top = new LinearLayout(this);
        top.setOrientation(LinearLayout.HORIZONTAL);
        top.setGravity(Gravity.CENTER_VERTICAL);

        TextView avatar = text(c.name.substring(0, 1), 16, Color.WHITE, Typeface.BOLD);
        avatar.setGravity(Gravity.CENTER);
        avatar.setBackground(round(NAVY, 16));
        top.addView(avatar, new LinearLayout.LayoutParams(dp(44), dp(44)));

        LinearLayout info = new LinearLayout(this);
        info.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams infoLp = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1);
        infoLp.setMargins(dp(11), 0, dp(8), 0);
        top.addView(info, infoLp);

        TextView name = text(c.name, 16, TEXT, Typeface.BOLD);
        info.addView(name);
        TextView group = text(c.group, 11, MUTED, Typeface.NORMAL);
        LinearLayout.LayoutParams gLp = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        gLp.setMargins(0, dp(2), 0, 0);
        info.addView(group, gLp);

        TextView phone = text(c.phone, 14, BLUE, Typeface.BOLD);
        top.addView(phone);
        card.addView(top);

        EditText memo = new EditText(this);
        memo.setText(prefs.getString("memo_" + c.name, c.defaultMemo));
        memo.setTextSize(13);
        memo.setTextColor(TEXT);
        memo.setLineSpacing(0, 1.15f);
        memo.setMinLines(3);
        memo.setMaxLines(8);
        memo.setGravity(Gravity.TOP | Gravity.START);
        memo.setPadding(dp(13), dp(12), dp(13), dp(12));
        memo.setBackground(stroke(Color.rgb(249, 250, 251), LINE, 14, 1));
        LinearLayout.LayoutParams mLp = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        mLp.setMargins(0, dp(13), 0, dp(10));
        card.addView(memo, mLp);
        memo.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            @Override public void onTextChanged(CharSequence s, int start, int before, int count) {
                prefs.edit().putString("memo_" + c.name, s.toString()).apply();
            }
            @Override public void afterTextChanged(Editable s) {}
        });

        TextView call = text("전화하기  ·  " + c.phone, 14, Color.WHITE, Typeface.BOLD);
        call.setGravity(Gravity.CENTER);
        call.setBackground(round(BLUE, 14));
        call.setOnClickListener(v -> {
            String digits = c.phone.replace("-", "");
            startActivity(new Intent(Intent.ACTION_DIAL, Uri.parse("tel:" + digits)));
        });
        card.addView(call, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(50)));
        content.addView(card);
    }

    private LinearLayout card(int radius) {
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setPadding(dp(15), dp(15), dp(15), dp(15));
        card.setBackground(stroke(Color.WHITE, LINE, radius, 1));
        card.setElevation(dp(1));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        lp.setMargins(0, 0, 0, dp(10));
        card.setLayoutParams(lp);
        return card;
    }

    private void addSection(String label, String count) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(3), dp(12), dp(3), dp(9));
        TextView title = text(label, 14, TEXT, Typeface.BOLD);
        row.addView(title, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1));
        if (count != null && !count.isEmpty()) {
            TextView c = text(count, 12, MUTED, Typeface.BOLD);
            c.setPadding(dp(9), dp(4), dp(9), dp(4));
            c.setBackground(round(GRAY_SOFT, 999));
            row.addView(c);
        }
        content.addView(row);
    }

    private int getState(CheckItem item) {
        return prefs.getInt("state_" + item.id, item.initialState);
    }

    private TextView text(String value, int sp, int color, int style) {
        TextView v = new TextView(this);
        v.setText(value);
        v.setTextSize(sp);
        v.setTextColor(color);
        v.setTypeface(Typeface.create("sans-serif", style));
        return v;
    }

    private GradientDrawable round(int color, int radiusDp) {
        GradientDrawable d = new GradientDrawable();
        d.setColor(color);
        d.setCornerRadius(dp(radiusDp));
        return d;
    }

    private GradientDrawable stroke(int fill, int strokeColor, int radiusDp, int strokeDp) {
        GradientDrawable d = round(fill, radiusDp);
        d.setStroke(dp(strokeDp), strokeColor);
        return d;
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private static class CheckItem {
        final String id, group, title, desc;
        final int initialState;
        CheckItem(String id, String group, String title, String desc, int initialState) {
            this.id = id;
            this.group = group;
            this.title = title;
            this.desc = desc;
            this.initialState = initialState;
        }
    }

    private static class Contact {
        final String group, name, phone, defaultMemo;
        Contact(String group, String name, String phone, String defaultMemo) {
            this.group = group;
            this.name = name;
            this.phone = phone;
            this.defaultMemo = defaultMemo;
        }
    }
}
