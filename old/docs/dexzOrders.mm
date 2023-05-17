<map version="freeplane 1.6.0">
<!--To view this file, download free mind mapping software Freeplane from http://freeplane.sourceforge.net -->
<node TEXT="dexzOrders" FOLDED="false" ID="ID_261188178" CREATED="1535278835638" MODIFIED="1537621858176" STYLE="oval">
<font SIZE="18"/>
<hook NAME="MapStyle" zoom="0.8514563">
    <properties fit_to_viewport="false" edgeColorConfiguration="#808080ff,#ff0000ff,#0000ffff,#00ff00ff,#ff00ffff,#00ffffff,#7c0000ff,#00007cff,#007c00ff,#7c007cff,#007c7cff,#7c7c00ff"/>

<map_styles>
<stylenode LOCALIZED_TEXT="styles.root_node" STYLE="oval" UNIFORM_SHAPE="true" VGAP_QUANTITY="24.0 pt">
<font SIZE="24"/>
<stylenode LOCALIZED_TEXT="styles.predefined" POSITION="right" STYLE="bubble">
<stylenode LOCALIZED_TEXT="default" ICON_SIZE="12.0 pt" COLOR="#000000" STYLE="fork">
<font NAME="SansSerif" SIZE="10" BOLD="false" ITALIC="false"/>
</stylenode>
<stylenode LOCALIZED_TEXT="defaultstyle.details"/>
<stylenode LOCALIZED_TEXT="defaultstyle.attributes">
<font SIZE="9"/>
</stylenode>
<stylenode LOCALIZED_TEXT="defaultstyle.note" COLOR="#000000" BACKGROUND_COLOR="#ffffff" TEXT_ALIGN="LEFT"/>
<stylenode LOCALIZED_TEXT="defaultstyle.floating">
<edge STYLE="hide_edge"/>
<cloud COLOR="#f0f0f0" SHAPE="ROUND_RECT"/>
</stylenode>
</stylenode>
<stylenode LOCALIZED_TEXT="styles.user-defined" POSITION="right" STYLE="bubble">
<stylenode LOCALIZED_TEXT="styles.topic" COLOR="#18898b" STYLE="fork">
<font NAME="Liberation Sans" SIZE="10" BOLD="true"/>
</stylenode>
<stylenode LOCALIZED_TEXT="styles.subtopic" COLOR="#cc3300" STYLE="fork">
<font NAME="Liberation Sans" SIZE="10" BOLD="true"/>
</stylenode>
<stylenode LOCALIZED_TEXT="styles.subsubtopic" COLOR="#669900">
<font NAME="Liberation Sans" SIZE="10" BOLD="true"/>
</stylenode>
<stylenode LOCALIZED_TEXT="styles.important">
<icon BUILTIN="yes"/>
</stylenode>
</stylenode>
<stylenode LOCALIZED_TEXT="styles.AutomaticLayout" POSITION="right" STYLE="bubble">
<stylenode LOCALIZED_TEXT="AutomaticLayout.level.root" COLOR="#000000" STYLE="oval" SHAPE_HORIZONTAL_MARGIN="10.0 pt" SHAPE_VERTICAL_MARGIN="10.0 pt">
<font SIZE="18"/>
</stylenode>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,1" COLOR="#0033ff">
<font SIZE="16"/>
</stylenode>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,2" COLOR="#00b439">
<font SIZE="14"/>
</stylenode>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,3" COLOR="#990000">
<font SIZE="12"/>
</stylenode>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,4" COLOR="#111111">
<font SIZE="10"/>
</stylenode>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,5"/>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,6"/>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,7"/>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,8"/>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,9"/>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,10"/>
<stylenode LOCALIZED_TEXT="AutomaticLayout.level,11"/>
</stylenode>
</stylenode>
</map_styles>
</hook>
<hook NAME="AutomaticEdgeColor" COUNTER="6" RULE="ON_BRANCH_CREATION"/>
<node TEXT="Maker order&#xa;Buy baseTokens baseToken&#xa;@ price baseToken/quoteToken" POSITION="left" ID="ID_20605085" CREATED="1535278854798" MODIFIED="1535313719528" HGAP_QUANTITY="-23.499998882412942 pt" VSHIFT_QUANTITY="-118.4999964684249 pt">
<edge COLOR="#0000ff"/>
<cloud COLOR="#ff9999" SHAPE="ARC"/>
<hook NAME="FreeNode"/>
<node TEXT="Example" ID="ID_1294001925" CREATED="1535288816052" MODIFIED="1535288818259">
<node TEXT="Taker sells 1,000 GNT&#xa;@ 0.00054087 GNT/ETH" ID="ID_768943653" CREATED="1535279043193" MODIFIED="1535288756236">
<node TEXT="Taker -&gt; Maker (k x baseTokens) baseToken" ID="ID_543967822" CREATED="1535279107384" MODIFIED="1535302956029"/>
</node>
<node TEXT="Maker buys 1,000 GNT&#xa;@ 0.00054087 GNT/ETH" ID="ID_1581979210" CREATED="1535278938442" MODIFIED="1535279185839">
<node TEXT="Maker -&gt; Taker (k x baseTokens x price / 1e18) quoteToken" ID="ID_574734784" CREATED="1535279096879" MODIFIED="1535302948727"/>
</node>
</node>
<node TEXT="takerSell(amountBaseTokens)" ID="ID_1921685397" CREATED="1535279566582" MODIFIED="1535301201990">
<node TEXT="require(now &lt;= expiry)" ID="ID_785029506" CREATED="1535279597305" MODIFIED="1535289066654"/>
<node TEXT="require(orderType == OrderType.BUY)" ID="ID_1803237818" CREATED="1535301344860" MODIFIED="1535301355332"/>
<node TEXT="Taker _baseTokens = min" ID="ID_827935988" CREATED="1535279770929" MODIFIED="1535303210772">
<node TEXT="order.amount" ID="ID_1701196396" CREATED="1535279790132" MODIFIED="1535303142939"/>
<node TEXT="amountBaseToken" ID="ID_1878358939" CREATED="1535303107856" MODIFIED="1535303111609"/>
<node TEXT="baseToken.allowance(msg.sender, this)" ID="ID_36702287" CREATED="1535279698866" MODIFIED="1535303233167"/>
<node TEXT="baseToken.balanceOf(msg.sender)" ID="ID_830966651" CREATED="1535279821892" MODIFIED="1535303161011"/>
</node>
<node TEXT="Maker _quoteTokens = min" ID="ID_1697008384" CREATED="1535279609050" MODIFIED="1535303063237">
<node TEXT="order.amount x price / 1e18" ID="ID_1554899459" CREATED="1535303027586" MODIFIED="1535303038996"/>
<node TEXT="amountBaseTokens x price / 1e18" ID="ID_203680376" CREATED="1535279654773" MODIFIED="1535280083562"/>
<node TEXT="quoteToken.balanceOf(this)" ID="ID_1190228265" CREATED="1535279718918" MODIFIED="1535303093889"/>
</node>
<node TEXT="_baseTokens = min" ID="ID_292090439" CREATED="1535279894959" MODIFIED="1535279997186">
<node TEXT="Maker _quoteTokens x 1e18 / price" ID="ID_950652643" CREATED="1535279929848" MODIFIED="1535303200823"/>
<node TEXT="Taker _baseTokens" ID="ID_1157598207" CREATED="1535279945548" MODIFIED="1535303207432"/>
</node>
<node TEXT="_quoteTokens = _baseTokens x price / 1e18" ID="ID_653718630" CREATED="1535279955625" MODIFIED="1535280037040"/>
<node TEXT="require(_baseTokens &gt; 0 &amp;&amp; _quoteTokens &gt; 0)" ID="ID_1027709908" CREATED="1535280569817" MODIFIED="1535280578813"/>
<node TEXT="Log TakerSold" ID="ID_1558921520" CREATED="1535280149803" MODIFIED="1535280159936"/>
<node TEXT="Reduce order.amount or remove order if 0" ID="ID_325988327" CREATED="1535288646015" MODIFIED="1535288675948"/>
<node TEXT="baseToken.transferFrom(msg.sender, this, _baseTokens)" ID="ID_486125374" CREATED="1535280160866" MODIFIED="1535303275855">
<node TEXT="Check before and after balance" ID="ID_243155582" CREATED="1535280228988" MODIFIED="1535280235637"/>
</node>
<node TEXT="quoteToken.transfer(msg.sender, _quoteTokens)" ID="ID_1084187465" CREATED="1535280201780" MODIFIED="1535303287071">
<node TEXT="Check before and after balance" ID="ID_1096925098" CREATED="1535280237354" MODIFIED="1535280241611"/>
</node>
</node>
</node>
<node TEXT="Maker order&#xa;Sell baseTokens baseToken&#xa;@ price baseToken/quoteToken" POSITION="left" ID="ID_1972648437" CREATED="1535278896890" MODIFIED="1535313728215" HGAP_QUANTITY="-15.999999105930355 pt" VSHIFT_QUANTITY="240.7499928250911 pt">
<edge COLOR="#ff9966"/>
<cloud COLOR="#99ff99" SHAPE="ARC"/>
<hook NAME="FreeNode"/>
<node TEXT="Example" ID="ID_1395530092" CREATED="1535288830551" MODIFIED="1535288832193">
<node TEXT="Taker buys 1,000 GNT&#xa;@ 0.00055087 GNT/ETH" ID="ID_1393863044" CREATED="1535279060087" MODIFIED="1535288752926">
<node TEXT="Taker -&gt; Maker (k x baseTokens x price / 1e18) quoteToken" ID="ID_1471707747" CREATED="1535279163496" MODIFIED="1535303358251"/>
</node>
<node TEXT="Maker sells 1,000 GNT&#xa;@ 0.00055087 GNT/ETH" ID="ID_978861554" CREATED="1535278964086" MODIFIED="1535279199918">
<node TEXT="Maker -&gt; Taker (k x baseTokens) baseToken" ID="ID_1526666518" CREATED="1535279147144" MODIFIED="1535303361494"/>
</node>
</node>
<node TEXT="takerBuy(amountBaseTokens)" ID="ID_795874113" CREATED="1535279584484" MODIFIED="1535301208069">
<node TEXT="require(now &lt;= expiry)" ID="ID_804526356" CREATED="1535280263415" MODIFIED="1535289074147"/>
<node TEXT="require(orderType == OrderType.SELL)" ID="ID_1024287721" CREATED="1535301361323" MODIFIED="1535301369303"/>
<node TEXT="Taker _quoteTokens = min" ID="ID_1882416314" CREATED="1535280266855" MODIFIED="1535303486072">
<node TEXT="order.amount x price / 1e18" ID="ID_1143230970" CREATED="1535303492186" MODIFIED="1535303522262"/>
<node TEXT="amountBaseTokens x price / 1e18" ID="ID_1433967997" CREATED="1535280280565" MODIFIED="1535303528917"/>
<node TEXT="quoteToken.allowance(msg.sender, this)" ID="ID_792624534" CREATED="1535280292036" MODIFIED="1535303556634"/>
<node TEXT="quoteToken.balanceOf(msg.sender)" ID="ID_1673742373" CREATED="1535280303437" MODIFIED="1535303563104"/>
</node>
<node TEXT="Maker _baseTokens = min" ID="ID_1291616908" CREATED="1535280314246" MODIFIED="1535303571597">
<node TEXT="order.amount" ID="ID_923637771" CREATED="1535303579518" MODIFIED="1535303583286"/>
<node TEXT="amountBaseToken" ID="ID_949780803" CREATED="1535303590482" MODIFIED="1535303594814"/>
<node TEXT="baseToken.balanceOf(this)" ID="ID_342244687" CREATED="1535280351787" MODIFIED="1535303624730"/>
</node>
<node TEXT="_baseTokens = min" ID="ID_618690553" CREATED="1535280376701" MODIFIED="1535280383962">
<node TEXT="Maker _baseTokens" ID="ID_1885828720" CREATED="1535280410714" MODIFIED="1535303650406"/>
<node TEXT="Taker _quoteTokens x 1e18 / price" ID="ID_1248220515" CREATED="1535280398629" MODIFIED="1535303666619"/>
</node>
<node TEXT="_quoteTokens = _baseTokens x price / 1e18" ID="ID_1745515120" CREATED="1535280431173" MODIFIED="1535303675511"/>
<node TEXT="require(_baseTokens &gt; 0 &amp;&amp; _quoteTokens &gt; 0)" ID="ID_1074105088" CREATED="1535280550216" MODIFIED="1535280561692"/>
<node TEXT="Log TakerBought" ID="ID_766193978" CREATED="1535280441203" MODIFIED="1535280446470"/>
<node TEXT="Reduce order.amount or remove order if 0" ID="ID_181586748" CREATED="1535288694232" MODIFIED="1535288703315"/>
<node TEXT="quoteToken.transferFrom(msg.sender, this, _quoteTokens)" ID="ID_1736160744" CREATED="1535280447641" MODIFIED="1535303702203">
<node TEXT="Check before and after" ID="ID_768527945" CREATED="1535280469225" MODIFIED="1535280472495"/>
</node>
<node TEXT="baseToken.transfer(msg.sender, _baseTokens)" ID="ID_1641615747" CREATED="1535280473693" MODIFIED="1535303719472">
<node TEXT="Check before and after" ID="ID_1116409774" CREATED="1535280487103" MODIFIED="1535280490625"/>
</node>
</node>
</node>
<node TEXT="Exchanger" POSITION="right" ID="ID_1033636624" CREATED="1535313095901" MODIFIED="1535313101089">
<edge COLOR="#7c0000"/>
<node TEXT="Example" ID="ID_1461585128" CREATED="1535313367736" MODIFIED="1535313371300">
<node TEXT="DW1" ID="ID_1547058521" CREATED="1535313305686" MODIFIED="1535313309825">
<node TEXT="B 1,000 GNT @ 0.00054087" ID="ID_781462373" CREATED="1535313316635" MODIFIED="1535313340256">
<node TEXT="+0.54087 ETH" ID="ID_1084228630" CREATED="1535313470920" MODIFIED="1535313487053"/>
</node>
</node>
<node TEXT="DW2" ID="ID_150914980" CREATED="1535313312120" MODIFIED="1535313314709">
<node TEXT="S 1,000 GNT @ 0.00054087" ID="ID_1482485679" CREATED="1535313343229" MODIFIED="1535313359561">
<node TEXT="+2,000 GNT" ID="ID_1039030979" CREATED="1535313490031" MODIFIED="1535313495761"/>
</node>
</node>
</node>
<node TEXT="" ID="ID_1320284864" CREATED="1535313429174" MODIFIED="1535313429174"/>
</node>
</node>
</map>
