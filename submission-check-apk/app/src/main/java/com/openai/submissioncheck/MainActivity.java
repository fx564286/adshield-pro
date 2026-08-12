package com.openai.submissioncheck;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.List;

public class MainActivity extends Activity {
    private static final int TODO = 0;
    private static final int DOING = 1;
    private static final int DONE = 2;

    private SharedPreferences prefs;
    private LinearLayout content;
    private TextView summary;
    private Button tabCheck;
    private Button tabContacts;
    private boolean showingContacts = false;

    private final List<CheckItem> checks = new ArrayList<>();
    private final List<Contact> contacts = new ArrayList<>();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        prefs = getSharedPreferences("submission_check", MODE_PRIVATE);
        seedData();
        buildShell();
        showChecklist();
    }

    private void seedData() {
        checks.add(new CheckItem("1-1", "대출금", "대출금 최종사용처 정리", "양식에 맞춰 최종 사용처 정리", TODO));
        checks.add(new CheckItem("1-2", "대출금", "대출금 입금 계좌 정보 및 날짜", "대출금 입금받은 계좌 정보와 날짜 최종 확인", DONE));
        checks.add(new CheckItem("2-1", "신용카드", "신용카드 이용내역 정리", "제출용으로 이용내역 정리", TODO));
        checks.add(new CheckItem("2-2", "신용카드", "카드사별 이용내역 발급", "2025.08.01~2026.07.31 / 현대·롯데·신한·국민·삼성", DONE));
        checks.add(new CheckItem("3-1", "활동성계좌", "50만원 이상 입출금 정리", "2025.06.01~2026.07.31", TODO));
        checks.add(new CheckItem("3-2", "활동성계좌", "제출 계좌 거래내역 준비", "은행·증권사·카카오페이 거래내역", DOING));
        checks.add(new CheckItem("4-1", "주식 소명", "출금 사용처 정리", "주식 관련 출금 최종 사용처 정리", TODO));
        checks.add(new CheckItem("4-2", "주식 소명", "투자내역 정리", "증권사별·기간별 투자 흐름 정리", TODO));
        checks.add(new CheckItem("4-3", "주식 소명", "증권사 거래내역 발급", "2025.01.01~2026.07.31 / 입출금·매매 모두 포함", TODO));
        checks.add(new CheckItem("4-4", "주식 소명", "잔고증명서", "현재 기준", TODO));
        checks.add(new CheckItem("4-5", "주식 소명", "투자 손실 상세 진술서", "투자 시작부터 개인회생 신청 시점까지", TODO));
        checks.add(new CheckItem("4-6", "주식 소명", "기간별 수익률 조회", "기간수익률·계좌수익률·투자손익 등", TODO));

        contacts.add(new Contact("카드사", "현대카드", "1577-6000"));
        contacts.add(new Contact("카드사", "롯데카드", "1588-8100"));
        contacts.add(new Contact("카드사", "신한카드", "1544-7000"));
        contacts.add(new Contact("카드사", "KB국민카드", "1588-1688"));
        contacts.add(new Contact("카드사", "삼성카드", "1588-8700"));

        contacts.add(new Contact("은행", "케이뱅크", "1522-1000"));
        contacts.add(new Contact("은행", "토스뱅크", "1661-7654"));
        contacts.add(new Contact("은행", "하나은행", "1588-1111"));

        contacts.add(new Contact("증권사", "KB증권", "1588-6611"));
        contacts.add(new Contact("증권사", "NH투자증권", "1544-0000"));
        contacts.add(new Contact("증권사", "메리츠증권", "1588-3400"));
        contacts.add(new Contact("증권사", "신한투자증권", "1588-0365"));
        contacts.add(new Contact("증권사", "카카오페이증권", "1600-8515"));
        contacts.add(new Contact("증권사", "토스증권", "1599-7987"));
        contacts.add(new Contact("증권사", "하나증권", "1588-3111"));
        contacts.add(new Contact("증권사", "한국투자증권", "1544-5000"));

        contacts.add(new Contact("간편결제", "카카오페이", "1644-7405"));
    }

    private void buildShell() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.parseColor("#F4F6F8"));

        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.VERTICAL);
        header.setPadding(dp(18), dp(18), dp(18), dp(14));
        header.setBackgroundColor(Color.parseColor("#101828"));

        TextView title = new TextView(this);
        title.setText("개인회생 제출서류");
        title.setTextColor(Color.WHITE);
        title.setTextSize(18);
        title.setTypeface(null, 1);
        header.addView(title);

        summary = new TextView(this);
        summary.setTextColor(Color.WHITE);
        summary.setTextSize(26);
        summary.setTypeface(null, 1);
        summary.setPadding(0, dp(8), 0, 0);
        header.addView(summary);
        root.addView(header);

        LinearLayout tabs = new LinearLayout(this);
        tabs.setOrientation(LinearLayout.HORIZONTAL);
        tabs.setPadding(dp(10), dp(10), dp(10), dp(6));

        tabCheck = new Button(this);
        tabCheck.setText("✓ 서류 체크");
        tabCheck.setAllCaps(false);
        tabCheck.setOnClickListener(v -> {
            showingContacts = false;
            showChecklist();
        });
        tabs.addView(tabCheck, new LinearLayout.LayoutParams(0, dp(48), 1));

        tabContacts = new Button(this);
        tabContacts.setText("☎ 고객센터");
        tabContacts.setAllCaps(false);
        tabContacts.setOnClickListener(v -> {
            showingContacts = true;
            showContacts();
        });
        LinearLayout.LayoutParams tabLp = new LinearLayout.LayoutParams(0, dp(48), 1);
        tabLp.setMargins(dp(8), 0, 0, 0);
        tabs.addView(tabContacts, tabLp);
        root.addView(tabs);

        ScrollView scroll = new ScrollView(this);
        content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(dp(12), dp(4), dp(12), dp(28));
        scroll.addView(content);
        root.addView(scroll, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1));

        setContentView(root);
    }

    private void updateHeader() {
        int done = 0;
        for (CheckItem item : checks) {
            if (getState(item) == DONE) done++;
        }
        int pct = Math.round(done * 100f / checks.size());
        if (showingContacts) {
            summary.setText(contacts.size() + "개 기관 · 터치해서 전화");
        } else {
            summary.setText(done + " / " + checks.size() + " 완료 · " + pct + "%");
        }
        tabCheck.setBackgroundTintList(ColorStateList.valueOf(Color.parseColor(showingContacts ? "#E4E7EC" : "#D1E9FF")));
        tabContacts.setBackgroundTintList(ColorStateList.valueOf(Color.parseColor(showingContacts ? "#D1E9FF" : "#E4E7EC")));
    }

    private void showChecklist() {
        showingContacts = false;
        content.removeAllViews();
        updateHeader();

        String lastGroup = "";
        for (CheckItem item : checks) {
            if (!item.group.equals(lastGroup)) {
                addSection(item.group);
                lastGroup = item.group;
            }
            addCheckCard(item);
        }
    }

    private void addCheckCard(CheckItem item) {
        LinearLayout card = card();

        TextView id = new TextView(this);
        id.setText(item.id + "  " + item.title);
        id.setTextColor(Color.parseColor("#101828"));
        id.setTextSize(16);
        id.setTypeface(null, 1);
        card.addView(id);

        TextView desc = new TextView(this);
        desc.setText(item.desc);
        desc.setTextColor(Color.parseColor("#667085"));
        desc.setTextSize(13);
        desc.setPadding(0, dp(5), 0, dp(10));
        card.addView(desc);

        Button state = new Button(this);
        state.setAllCaps(false);
        int current = getState(item);
        state.setText(stateLabel(current) + " · 눌러서 변경");
        state.setTextColor(Color.parseColor(stateTextColor(current)));
        state.setBackgroundTintList(ColorStateList.valueOf(Color.parseColor(stateBgColor(current))));
        state.setOnClickListener(v -> {
            int next = (getState(item) + 1) % 3;
            prefs.edit().putInt("state_" + item.id, next).apply();
            showChecklist();
        });
        card.addView(state, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(46)));
        content.addView(card);
    }

    private void showContacts() {
        showingContacts = true;
        content.removeAllViews();
        updateHeader();

        TextView notice = new TextView(this);
        notice.setText("전화하기를 누르면 전화 앱에 번호가 입력됩니다. 계좌번호나 요청 내용을 아래 메모 칸에 적으면 이 휴대폰에만 저장됩니다.");
        notice.setTextColor(Color.parseColor("#1849A9"));
        notice.setTextSize(13);
        notice.setPadding(dp(14), dp(13), dp(14), dp(13));
        notice.setBackgroundColor(Color.parseColor("#EFF8FF"));
        LinearLayout.LayoutParams nlp = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        nlp.setMargins(0, 0, 0, dp(10));
        content.addView(notice, nlp);

        String lastGroup = "";
        for (Contact c : contacts) {
            if (!c.group.equals(lastGroup)) {
                addSection(c.group);
                lastGroup = c.group;
            }
            addContactCard(c);
        }
    }

    private void addContactCard(Contact c) {
        LinearLayout card = card();

        LinearLayout top = new LinearLayout(this);
        top.setOrientation(LinearLayout.HORIZONTAL);
        top.setGravity(Gravity.CENTER_VERTICAL);

        TextView name = new TextView(this);
        name.setText(c.name);
        name.setTextColor(Color.parseColor("#101828"));
        name.setTextSize(17);
        name.setTypeface(null, 1);
        top.addView(name, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1));

        TextView phone = new TextView(this);
        phone.setText(c.phone);
        phone.setTextColor(Color.parseColor("#175CD3"));
        phone.setTextSize(15);
        phone.setTypeface(null, 1);
        top.addView(phone);
        card.addView(top);

        EditText memo = new EditText(this);
        memo.setHint("계좌번호 / 요청할 내용 메모 (기기에만 저장)");
        memo.setText(prefs.getString("memo_" + c.name, ""));
        memo.setTextSize(13);
        memo.setSingleLine(false);
        memo.setMinLines(1);
        memo.setMaxLines(3);
        memo.setPadding(dp(10), dp(8), dp(10), dp(8));
        LinearLayout.LayoutParams mlp = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        mlp.setMargins(0, dp(10), 0, dp(8));
        card.addView(memo, mlp);
        memo.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            @Override public void onTextChanged(CharSequence s, int start, int before, int count) {
                prefs.edit().putString("memo_" + c.name, s.toString()).apply();
            }
            @Override public void afterTextChanged(Editable s) {}
        });

        Button call = new Button(this);
        call.setText("☎  " + c.phone + " 전화하기");
        call.setAllCaps(false);
        call.setTextColor(Color.WHITE);
        call.setBackgroundTintList(ColorStateList.valueOf(Color.parseColor("#175CD3")));
        call.setOnClickListener(v -> {
            String digits = c.phone.replace("-", "");
            Intent intent = new Intent(Intent.ACTION_DIAL, Uri.parse("tel:" + digits));
            startActivity(intent);
        });
        card.addView(call, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(48)));
        content.addView(card);
    }

    private LinearLayout card() {
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setPadding(dp(15), dp(14), dp(15), dp(14));
        card.setBackgroundColor(Color.WHITE);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        lp.setMargins(0, 0, 0, dp(9));
        card.setLayoutParams(lp);
        card.setElevation(dp(1));
        return card;
    }

    private void addSection(String label) {
        TextView section = new TextView(this);
        section.setText(label);
        section.setTextColor(Color.parseColor("#667085"));
        section.setTextSize(14);
        section.setTypeface(null, 1);
        section.setPadding(dp(3), dp(10), 0, dp(8));
        content.addView(section);
    }

    private int getState(CheckItem item) {
        return prefs.getInt("state_" + item.id, item.initialState);
    }

    private String stateLabel(int state) {
        if (state == DONE) return "✓ 완료";
        if (state == DOING) return "◐ 진행중";
        return "○ 미완료";
    }

    private String stateBgColor(int state) {
        if (state == DONE) return "#ECFDF3";
        if (state == DOING) return "#FFF4E5";
        return "#F2F4F7";
    }

    private String stateTextColor(int state) {
        if (state == DONE) return "#067647";
        if (state == DOING) return "#B54708";
        return "#475467";
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private static class CheckItem {
        final String id;
        final String group;
        final String title;
        final String desc;
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
        final String group;
        final String name;
        final String phone;

        Contact(String group, String name, String phone) {
            this.group = group;
            this.name = name;
            this.phone = phone;
        }
    }
}
