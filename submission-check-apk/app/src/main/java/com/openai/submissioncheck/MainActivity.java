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
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.List;

public class MainActivity extends Activity {
    private static final int TODO=0, DOING=1, DONE=2;
    private SharedPreferences prefs;
    private LinearLayout content;
    private TextView summary;
    private Button tabCheck, tabContacts;
    private boolean showingContacts=false;
    private final List<CheckItem> checks=new ArrayList<>();
    private final List<Contact> contacts=new ArrayList<>();

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        prefs=getSharedPreferences("submission_check",MODE_PRIVATE);
        seedData(); buildShell(); showChecklist();
    }

    private void seedData() {
        checks.add(new CheckItem("1-1","대출금","대출금 최종사용처 정리","양식에 맞춰 최종 사용처 정리",TODO));
        checks.add(new CheckItem("1-2","대출금","대출금 입금 계좌 정보 및 날짜","대출금 입금받은 계좌 정보와 날짜 최종 확인",DONE));
        checks.add(new CheckItem("2-1","신용카드","신용카드 이용내역 정리","제출용으로 이용내역 정리",TODO));
        checks.add(new CheckItem("2-2","신용카드","카드사별 이용내역 발급","2025.08.01~2026.07.31 / 현대·롯데·신한·국민·삼성",DONE));
        checks.add(new CheckItem("3-1","활동성계좌","50만원 이상 입출금 정리","2025.06.01~2026.07.31",TODO));
        checks.add(new CheckItem("3-2","활동성계좌","제출 계좌 거래내역 준비","은행·증권사·카카오페이 거래내역",DOING));
        checks.add(new CheckItem("4-1","주식 소명","출금 사용처 정리","주식 관련 출금 최종 사용처 정리",TODO));
        checks.add(new CheckItem("4-2","주식 소명","투자내역 정리","증권사별·기간별 투자 흐름 정리",TODO));
        checks.add(new CheckItem("4-3","주식 소명","증권사 거래내역 발급","2025.01.01~2026.07.31 / 입출금·매매 모두 포함",TODO));
        checks.add(new CheckItem("4-4","주식 소명","잔고증명서","현재 기준",TODO));
        checks.add(new CheckItem("4-5","주식 소명","투자 손실 상세 진술서","투자 시작부터 개인회생 신청 시점까지",TODO));
        checks.add(new CheckItem("4-6","주식 소명","기간별 수익률 조회","기간수익률·계좌수익률·투자손익 등",TODO));

        contacts.add(new Contact("카드사","현대카드","1577-6000","가가가가 가가가가(0000.00.00~0000.00.00) 가가 가가가 가가"));
        contacts.add(new Contact("카드사","롯데카드","1588-8100","나가가가 가가가가(0000.00.00~0000.00.00) 가가 가가가 가가"));
        contacts.add(new Contact("카드사","신한카드","1544-7000","다가가가 가가가가(0000.00.00~0000.00.00) 가가 가가가 가가"));
        contacts.add(new Contact("카드사","KB국민카드","1588-1688","라가가가 가가가가(0000.00.00~0000.00.00) 가가 가가가 가가"));
        contacts.add(new Contact("카드사","삼성카드","1588-8700","마가가가 가가가가(0000.00.00~0000.00.00) 가가 가가가 가가"));
        contacts.add(new Contact("은행","케이뱅크","1522-1000","0000000***00\n바가가가가 가가가가가(0000.00.00~0000.00.00)\n00가가 가가 가가가가가 가가"));
        contacts.add(new Contact("은행","토스뱅크","1661-7654","0000000***00\n사가가가가 가가가가가(0000.00.00~0000.00.00)\n00가가 가가 가가가가가 가가"));
        contacts.add(new Contact("은행","하나은행","1588-1111","000000000***00\n000000000***00\n아가가가가 가가가가가(0000.00.00~0000.00.00)\n00가가 가가 가가가가가 가가"));
        contacts.add(new Contact("증권사","KB증권","1588-6611","000000***00 · 000000***00\n자가 가가가 가가가가(0000.00.00~0000.00.00)\n가가 가가가 가 가가 가가 가가 가가 가가\n가가가가가(가가 가가)\n가가가가가가 가가"));
        contacts.add(new Contact("증권사","NH투자증권","1544-0000","000000***00\n차가 가가가 가가가가(0000.00.00~0000.00.00)\n가가 가가가 가 가가 가가 가가 가가 가가\n가가가가가(가가 가가)\n가가가가가가 가가"));
        contacts.add(new Contact("증권사","메리츠증권","1588-3400","00000***00\n카가 가가가 가가가가(0000.00.00~0000.00.00)\n가가 가가가 가 가가 가가 가가 가가 가가\n가가가가가(가가 가가)\n가가가가가가 가가"));
        contacts.add(new Contact("증권사","신한투자증권","1588-0365","000000***00\n타가 가가가 가가가가(0000.00.00~0000.00.00)\n가가 가가가 가 가가 가가 가가 가가 가가\n가가가가가(가가 가가)\n가가가가가가 가가"));
        contacts.add(new Contact("증권사","카카오페이증권","1600-8515","000000***00\n파가 가가가 가가가가(0000.00.00~0000.00.00)\n가가 가가가 가 가가 가가 가가 가가 가가\n가가가가가(가가 가가)\n가가가가가가 가가"));
        contacts.add(new Contact("증권사","토스증권","1599-7987","000000***00\n하가 가가가 가가가가(0000.00.00~0000.00.00)\n가가 가가가 가 가가 가가 가가 가가 가가\n가가가가가(가가 가가)\n가가가가가가 가가"));
        contacts.add(new Contact("증권사","하나증권","1588-3111","000000***00 · 000000***00 · 000000***00\n거가 가가가 가가가가(0000.00.00~0000.00.00)\n가가 가가가 가 가가 가가 가가 가가 가가\n가가가가가(가가 가가)\n가가가가가가 가가"));
        contacts.add(new Contact("증권사","한국투자증권","1544-5000","00000***00\n너가 가가가 가가가가(0000.00.00~0000.00.00)\n가가 가가가 가 가가 가가 가가 가가 가가\n가가가가가(가가 가가)\n가가가가가가 가가"));
        contacts.add(new Contact("간편결제","카카오페이","1644-7405","더가가가가 가가가가\n가가가가가 가가가가가(0000.00.00~0000.00.00)"));
    }

    private void buildShell() {
        LinearLayout root=new LinearLayout(this); root.setOrientation(LinearLayout.VERTICAL); root.setBackgroundColor(Color.parseColor("#F4F6F8"));
        LinearLayout header=new LinearLayout(this); header.setOrientation(LinearLayout.VERTICAL); header.setPadding(dp(18),dp(18),dp(18),dp(14)); header.setBackgroundColor(Color.parseColor("#101828"));
        TextView title=new TextView(this); title.setText("개인회생 제출서류"); title.setTextColor(Color.WHITE); title.setTextSize(18); title.setTypeface(null,1); header.addView(title);
        summary=new TextView(this); summary.setTextColor(Color.WHITE); summary.setTextSize(26); summary.setTypeface(null,1); summary.setPadding(0,dp(8),0,0); header.addView(summary); root.addView(header);
        LinearLayout tabs=new LinearLayout(this); tabs.setOrientation(LinearLayout.HORIZONTAL); tabs.setPadding(dp(10),dp(10),dp(10),dp(6));
        tabCheck=new Button(this); tabCheck.setText("✓ 서류 체크"); tabCheck.setAllCaps(false); tabCheck.setOnClickListener(v->showChecklist()); tabs.addView(tabCheck,new LinearLayout.LayoutParams(0,dp(48),1));
        tabContacts=new Button(this); tabContacts.setText("☎ 고객센터"); tabContacts.setAllCaps(false); tabContacts.setOnClickListener(v->showContacts()); LinearLayout.LayoutParams tlp=new LinearLayout.LayoutParams(0,dp(48),1); tlp.setMargins(dp(8),0,0,0); tabs.addView(tabContacts,tlp); root.addView(tabs);
        ScrollView scroll=new ScrollView(this); content=new LinearLayout(this); content.setOrientation(LinearLayout.VERTICAL); content.setPadding(dp(12),dp(4),dp(12),dp(28)); scroll.addView(content); root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
        setContentView(root);
    }

    private void updateHeader() {
        int done=0; for(CheckItem i:checks) if(getState(i)==DONE) done++;
        int pct=Math.round(done*100f/checks.size());
        summary.setText(showingContacts ? contacts.size()+"개 기관 · 터치해서 전화" : done+" / "+checks.size()+" 완료 · "+pct+"%");
        tabCheck.setBackgroundTintList(ColorStateList.valueOf(Color.parseColor(showingContacts?"#E4E7EC":"#D1E9FF")));
        tabContacts.setBackgroundTintList(ColorStateList.valueOf(Color.parseColor(showingContacts?"#D1E9FF":"#E4E7EC")));
    }

    private void showChecklist() {
        showingContacts=false; content.removeAllViews(); updateHeader(); String last="";
        for(CheckItem i:checks) { if(!i.group.equals(last)) { addSection(i.group); last=i.group; } addCheckCard(i); }
    }

    private void addCheckCard(CheckItem i) {
        LinearLayout card=card();
        TextView t=new TextView(this); t.setText(i.id+"  "+i.title); t.setTextColor(Color.parseColor("#101828")); t.setTextSize(16); t.setTypeface(null,1); card.addView(t);
        TextView d=new TextView(this); d.setText(i.desc); d.setTextColor(Color.parseColor("#667085")); d.setTextSize(13); d.setPadding(0,dp(5),0,dp(10)); card.addView(d);
        Button b=new Button(this); b.setAllCaps(false); int s=getState(i); b.setText(stateLabel(s)+" · 눌러서 변경"); b.setTextColor(Color.parseColor(stateTextColor(s))); b.setBackgroundTintList(ColorStateList.valueOf(Color.parseColor(stateBgColor(s))));
        b.setOnClickListener(v->{prefs.edit().putInt("state_"+i.id,(getState(i)+1)%3).apply(); showChecklist();});
        card.addView(b,new LinearLayout.LayoutParams(-1,dp(46))); content.addView(card);
    }

    private void showContacts() {
        showingContacts=true; content.removeAllViews(); updateHeader();
        TextView n=new TextView(this); n.setText("기존에 작성한 계좌번호와 요청 자료를 기본 메모로 넣었습니다. 수정한 내용은 이 휴대폰에만 저장됩니다."); n.setTextColor(Color.parseColor("#1849A9")); n.setTextSize(13); n.setPadding(dp(14),dp(13),dp(14),dp(13)); n.setBackgroundColor(Color.parseColor("#EFF8FF")); LinearLayout.LayoutParams nlp=new LinearLayout.LayoutParams(-1,-2); nlp.setMargins(0,0,0,dp(10)); content.addView(n,nlp);
        String last=""; for(Contact c:contacts) { if(!c.group.equals(last)) {addSection(c.group); last=c.group;} addContactCard(c); }
    }

    private void addContactCard(Contact c) {
        LinearLayout card=card(), top=new LinearLayout(this); top.setOrientation(LinearLayout.HORIZONTAL); top.setGravity(Gravity.CENTER_VERTICAL);
        TextView name=new TextView(this); name.setText(c.name); name.setTextColor(Color.parseColor("#101828")); name.setTextSize(17); name.setTypeface(null,1); top.addView(name,new LinearLayout.LayoutParams(0,-2,1));
        TextView phone=new TextView(this); phone.setText(c.phone); phone.setTextColor(Color.parseColor("#175CD3")); phone.setTextSize(15); phone.setTypeface(null,1); top.addView(phone); card.addView(top);
        EditText memo=new EditText(this); memo.setHint("계좌번호 / 요청할 내용 메모"); memo.setText(prefs.getString("memo_"+c.name,c.defaultMemo)); memo.setTextSize(13); memo.setSingleLine(false); memo.setMinLines(2); memo.setMaxLines(8); memo.setPadding(dp(10),dp(8),dp(10),dp(8)); LinearLayout.LayoutParams mlp=new LinearLayout.LayoutParams(-1,-2); mlp.setMargins(0,dp(10),0,dp(8)); card.addView(memo,mlp);
        memo.addTextChangedListener(new TextWatcher() { public void beforeTextChanged(CharSequence s,int st,int c1,int a){} public void onTextChanged(CharSequence s,int st,int b,int c1){prefs.edit().putString("memo_"+c.name,s.toString()).apply();} public void afterTextChanged(Editable e){} });
        Button call=new Button(this); call.setText("☎  "+c.phone+" 전화하기"); call.setAllCaps(false); call.setTextColor(Color.WHITE); call.setBackgroundTintList(ColorStateList.valueOf(Color.parseColor("#175CD3"))); call.setOnClickListener(v->startActivity(new Intent(Intent.ACTION_DIAL,Uri.parse("tel:"+c.phone.replace("-",""))))); card.addView(call,new LinearLayout.LayoutParams(-1,dp(48))); content.addView(card);
    }

    private LinearLayout card() {
        LinearLayout c=new LinearLayout(this); c.setOrientation(LinearLayout.VERTICAL); c.setPadding(dp(15),dp(14),dp(15),dp(14)); c.setBackgroundColor(Color.WHITE); LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,-2); lp.setMargins(0,0,0,dp(9)); c.setLayoutParams(lp); c.setElevation(dp(1)); return c;
    }
    private void addSection(String s) { TextView v=new TextView(this); v.setText(s); v.setTextColor(Color.parseColor("#667085")); v.setTextSize(14); v.setTypeface(null,1); v.setPadding(dp(3),dp(10),0,dp(8)); content.addView(v); }
    private int getState(CheckItem i) {return prefs.getInt("state_"+i.id,i.initialState);}
    private String stateLabel(int s) {return s==DONE?"✓ 완료":s==DOING?"◐ 진행중":"○ 미완료";}
    private String stateBgColor(int s) {return s==DONE?"#ECFDF3":s==DOING?"#FFF4E5":"#F2F4F7";}
    private String stateTextColor(int s) {return s==DONE?"#067647":s==DOING?"#B54708":"#475467";}
    private int dp(int v) {return Math.round(v*getResources().getDisplayMetrics().density);}

    private static class CheckItem {
        final String id,group,title,desc; final int initialState;
        CheckItem(String id,String group,String title,String desc,int initialState) {this.id=id;this.group=group;this.title=title;this.desc=desc;this.initialState=initialState;}
    }
    private static class Contact {
        final String group,name,phone,defaultMemo;
        Contact(String group,String name,String phone,String defaultMemo) {this.group=group;this.name=name;this.phone=phone;this.defaultMemo=defaultMemo;}
    }
}
