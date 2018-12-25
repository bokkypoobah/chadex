<map version="freeplane 1.6.0">
<!--To view this file, download free mind mapping software Freeplane from http://freeplane.sourceforge.net -->
<node TEXT="dexz" FOLDED="false" ID="ID_1531159334" CREATED="1535662994494" MODIFIED="1537621845915" STYLE="oval">
<font SIZE="18"/>
<hook NAME="MapStyle" background="#99ffff">
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
<hook NAME="AutomaticEdgeColor" COUNTER="11" RULE="ON_BRANCH_CREATION"/>
<node TEXT="SC" POSITION="right" ID="ID_1041709909" CREATED="1535663884265" MODIFIED="1535663885999">
<edge COLOR="#00ffff"/>
<node TEXT="Order" ID="ID_144515040" CREATED="1535663351118" MODIFIED="1535663901912">
<node TEXT="Order Data" ID="ID_107802926" CREATED="1535663229940" MODIFIED="1535663368102">
<node TEXT="key" ID="ID_1279452321" CREATED="1535663472785" MODIFIED="1535663576689">
<icon BUILTIN="password"/>
<node TEXT="owner" ID="ID_1003395618" CREATED="1535663256795" MODIFIED="1535663604780"/>
<node TEXT="orderType - Buy/Sell" ID="ID_807377583" CREATED="1535663240140" MODIFIED="1535663612822"/>
<node TEXT="baseToken" ID="ID_632309869" CREATED="1535663292339" MODIFIED="1535663616709"/>
<node TEXT="quoteToken" ID="ID_1294800496" CREATED="1535663299038" MODIFIED="1535663620186"/>
<node TEXT="price" ID="ID_373793567" CREATED="1535663310557" MODIFIED="1535663623852"/>
<node TEXT="expiry" ID="ID_1542958101" CREATED="1535663314877" MODIFIED="1535663627797"/>
</node>
<node TEXT="baseTokens" ID="ID_434690509" CREATED="1535663322307" MODIFIED="1535663326970"/>
<node TEXT="baseTokensFilled" ID="ID_437798754" CREATED="1535663327908" MODIFIED="1535663336347"/>
</node>
<node TEXT="Sample" ID="ID_1183013701" CREATED="1535663374710" MODIFIED="1535663382204">
<node TEXT="User1:0xa33a Buy 1234 DUNKEL @ 0.00054087 DUNKEL/WETH until Fri, 31 Aug 2018 07:46:26 AEST" ID="ID_799161499" CREATED="1535663382908" MODIFIED="1535663429295"/>
<node TEXT="User2:0xa44a Sell 1234 DUNKEL @ 0.00053087 DUNKEL/WETH until Fri, 31 Aug 2018 07:46:26 AEST" ID="ID_1771769935" CREATED="1535663447537" MODIFIED="1535663460879"/>
</node>
</node>
<node TEXT="Proxy" ID="ID_1567140190" CREATED="1535663637219" MODIFIED="1535663893986">
<node TEXT="approve(...) and transferFrom(...)" ID="ID_104831244" CREATED="1535663960052" MODIFIED="1535663973213"/>
<node TEXT="WETH vs ETH" ID="ID_673433165" CREATED="1535663988585" MODIFIED="1535663992107"/>
<node TEXT="Token whitelist" ID="ID_1233373386" CREATED="1535664737342" MODIFIED="1535664771874"/>
<node TEXT="Exchange whitelist" ID="ID_533740165" CREATED="1535664747891" MODIFIED="1535664754086"/>
<node TEXT="How to reduce need for trust here?" ID="ID_1053403093" CREATED="1535666295717" MODIFIED="1535666305090"/>
</node>
<node TEXT="Exchange" ID="ID_767304176" CREATED="1535663631822" MODIFIED="1535663911738">
<node TEXT="Orders[]" ID="ID_1315736257" CREATED="1535664003692" MODIFIED="1535665026903">
<node TEXT="addOrder(...)" ID="ID_526839348" CREATED="1535664793932" MODIFIED="1535664801178"/>
<node TEXT="increaseOrderBaseTokens(...)" ID="ID_1108329353" CREATED="1535664844210" MODIFIED="1535664909071"/>
<node TEXT="decreaseOrderBaseTokens(...)" ID="ID_1039843065" CREATED="1535664853360" MODIFIED="1535664915178"/>
<node TEXT="updateOrderPrice(...)" ID="ID_1428036852" CREATED="1535664955593" MODIFIED="1535664962630"/>
<node TEXT="updateOrderExpiry(...)" ID="ID_1214106790" CREATED="1535665005380" MODIFIED="1535665011806"/>
<node TEXT="removeOrder(...) - reset baseTokens to baseTokensFilled" ID="ID_53109015" CREATED="1535664816857" MODIFIED="1535664831527"/>
</node>
<node TEXT="takerBuy(Order order)" ID="ID_1300351315" CREATED="1535664010258" MODIFIED="1535664873255"/>
<node TEXT="takerSell(Order order)" ID="ID_918659972" CREATED="1535664014783" MODIFIED="1535664883011"/>
<node TEXT="exchange(Order[] orders)" ID="ID_828658697" CREATED="1535664018723" MODIFIED="1535664028469"/>
</node>
</node>
<node TEXT="UI" POSITION="left" ID="ID_66755670" CREATED="1535663940035" MODIFIED="1535663941703">
<edge COLOR="#7c0000"/>
</node>
<node TEXT="Backend" POSITION="left" ID="ID_1833414135" CREATED="1535663943320" MODIFIED="1535663945696">
<edge COLOR="#00007c"/>
</node>
<node TEXT="Alternatives" POSITION="left" ID="ID_853363375" CREATED="1535686751489" MODIFIED="1535686754230">
<edge COLOR="#007c7c"/>
<node TEXT="EtherDelta" ID="ID_289489237" CREATED="1535686832514" MODIFIED="1535686835221">
<node TEXT="SC" ID="ID_1421464355" CREATED="1535686835473" MODIFIED="1535687214053" LINK="https://etherscan.io/address/0x8d12a197cb00d4747a1fe03395095ce2a5cc6819#code"/>
<node TEXT="EtherDelta UI" ID="ID_1715746831" CREATED="1535686837364" MODIFIED="1535687256342" LINK="https://etherdelta.com/#EVE-ETH"/>
<node TEXT="ForkDelta UI" ID="ID_518040349" CREATED="1535687151014" MODIFIED="1535687155695" LINK="https://forkdelta.app/#!/trade/DAI-ETH"/>
<node TEXT="GammaDEX UI" ID="ID_836301201" CREATED="1535687179368" MODIFIED="1535687184278" LINK="https://gammadex.com/#!/exchange/DAI"/>
</node>
<node TEXT="CryptoDerivatives" ID="ID_626401880" CREATED="1535687258418" MODIFIED="1535687737932">
<node TEXT="SC" ID="ID_258839421" CREATED="1535687264049" MODIFIED="1535687345179" LINK="https://etherscan.io/address/0xa9f801f160fe6a866dd3404599350abbcaa95274#code"/>
<node TEXT="UI" ID="ID_787926560" CREATED="1535687266392" MODIFIED="1535687284387" LINK="https://cryptoderivatives.market/"/>
<node TEXT="JonnyLatte" ID="ID_1853448252" CREATED="1535692716894" MODIFIED="1535692780300" LINK="https://np.reddit.com/user/jonnylatte"/>
</node>
<node TEXT="IDEX" ID="ID_1752020786" CREATED="1535686758249" MODIFIED="1535686760425">
<node TEXT="SC" ID="ID_62414323" CREATED="1535686761497" MODIFIED="1535687027531" LINK="https://etherscan.io/address/0x2a0c0dbecc7e4d658f48e01e3fa353f44050c208#code"/>
<node TEXT="UI" ID="ID_702666277" CREATED="1535686827071" MODIFIED="1535686830730" LINK="https://idex.market/eth/eve"/>
</node>
<node TEXT="0x" ID="ID_1057480662" CREATED="1535687440532" MODIFIED="1535687442019">
<node TEXT="Website" ID="ID_604234612" CREATED="1535687448829" MODIFIED="1535687863445" LINK="https://0xproject.com/"/>
<node TEXT="GH" ID="ID_1372315891" CREATED="1535687846974" MODIFIED="1535687849839" LINK="https://github.com/0xProject/0x-monorepo/tree/development/packages/contracts/src/2.0.0/protocol"/>
<node TEXT="Docs" ID="ID_1256935574" CREATED="1535687477667" MODIFIED="1535687480158" LINK="https://0xproject.com/docs/contracts"/>
<node TEXT="Relayers" ID="ID_227528011" CREATED="1535687563404" MODIFIED="1535687688232" LINK="https://0xproject.com/wiki#List-of-Projects-Using-0x-Protocol">
<node TEXT="Paradex" ID="ID_224405577" CREATED="1535687566782" MODIFIED="1535687596869" LINK="https://paradex.io/market/weth-dai"/>
<node TEXT="The Ocean" ID="ID_1335064282" CREATED="1535687624405" MODIFIED="1535687639059" LINK="https://app.theocean.trade/dashboard/weth/zrx"/>
</node>
</node>
<node TEXT="Dexy" ID="ID_464529006" CREATED="1535687760838" MODIFIED="1535687762181">
<node TEXT="UI" ID="ID_297951925" CREATED="1535687764120" MODIFIED="1535687767310" LINK="https://app.dexy.exchange/#/markets"/>
<node TEXT="GH" ID="ID_1102146741" CREATED="1535687783425" MODIFIED="1535687800297" LINK="https://github.com/DexyProject/protocol"/>
</node>
<node TEXT="Kyber.Network" ID="ID_35872855" CREATED="1535692334568" MODIFIED="1535692337776">
<node TEXT="UI" ID="ID_1904071781" CREATED="1535692341418" MODIFIED="1535692400981" LINK="https://kyber.network/swap/eth_rdn"/>
<node TEXT="SC" ID="ID_1942052733" CREATED="1535692344389" MODIFIED="1535692437481" LINK="https://etherscan.io/address/0x818e6fecd516ecc3849daf6845e3ec868087b755#code"/>
<node TEXT="GH" ID="ID_308771076" CREATED="1535692438936" MODIFIED="1535692460454" LINK="https://github.com/KyberNetwork/smart-contracts/tree/master/contracts"/>
</node>
</node>
<node TEXT="Features" POSITION="left" ID="ID_284253010" CREATED="1535672794694" MODIFIED="1535672797213">
<edge COLOR="#007c00"/>
<node TEXT="ETH gasless?" ID="ID_1948863244" CREATED="1535672802309" MODIFIED="1535672808695"/>
<node TEXT="Fees" ID="ID_1098846673" CREATED="1535665068937" MODIFIED="1535665071340"/>
<node TEXT="Multihop Exchange" ID="ID_727667910" CREATED="1535687355534" MODIFIED="1535687361070"/>
<node TEXT="DAI Integration" ID="ID_1946085733" CREATED="1535687388846" MODIFIED="1535687407554"/>
<node TEXT="WETH Wrapping Integration" ID="ID_536830219" CREATED="1535687394464" MODIFIED="1535687403621"/>
<node TEXT="Permissionless Listing" ID="ID_340066796" CREATED="1535687642169" MODIFIED="1535687648708"/>
</node>
<node TEXT="Philosophy" POSITION="right" ID="ID_1690127954" CREATED="1535691174859" MODIFIED="1535691943206">
<edge COLOR="#7c7c00"/>
<node TEXT="Memes" ID="ID_1610557735" CREATED="1535691182482" MODIFIED="1535691185411" LINK="https://twitter.com/thejuicemedia/status/1034319416677130241"/>
<node TEXT="Crypto Experts" ID="ID_285042887" CREATED="1535691237207" MODIFIED="1535691241914" LINK="https://twitter.com/RyanSAdams/status/1034556123553124353"/>
<node TEXT="Narratives" ID="ID_1391031060" CREATED="1535691312508" MODIFIED="1535691343332" LINK="https://twitter.com/caitoz/status/1032066540219203584"/>
<node TEXT="Thot Leader" ID="ID_954744802" CREATED="1535691375276" MODIFIED="1535691380205" LINK="https://twitter.com/evan_van_ness/status/1034327606617886720"/>
<node TEXT="ICOs" ID="ID_1778993843" CREATED="1535691491564" MODIFIED="1535691494568" LINK="https://twitter.com/hrdwrknvrstps/status/1034896924917329921"/>
<node TEXT="MyCrypto / Nonce Too High" ID="ID_1359844184" CREATED="1535691639561" MODIFIED="1535691665006" LINK="https://ethereum.stackexchange.com/a/2809/1268"/>
<node TEXT="MyCrypto / Google Analytics" ID="ID_802650591" CREATED="1535691790814" MODIFIED="1535691804092" LINK="https://www.tokendaily.co/blog/the-blockchain-big-brother"/>
<node TEXT="Satoshi" ID="ID_203191358" CREATED="1535692841436" MODIFIED="1535692844192">
<node TEXT="Assembly" ID="ID_1320370568" CREATED="1535692880527" MODIFIED="1535692887074" LINK="https://twitter.com/alistairmilne/status/1033459254425014272"/>
<node TEXT="Base58" ID="ID_1584519197" CREATED="1535692901941" MODIFIED="1535692905855" LINK="https://twitter.com/el33th4xor/status/1034083468878245889"/>
</node>
</node>
</node>
</map>
