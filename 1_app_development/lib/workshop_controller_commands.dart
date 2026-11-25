part of 'workshop_controller.dart';

/// 배경 시간·미션 보상·아바타·온라인 보상·보상 광고·구매 명령.
/// [WorkshopController]에서 옮긴 그대로다(2026-11-23 안정화, 동작 변경 없음).
extension WorkshopCommands on WorkshopController {
  /// The day/night choice (4차 피드백 g10, ID9): the device's clock is
  /// free; a fixed day or night once bought ([ownsAvatar]).
  Future<bool> setBackgroundTime(String time)=>command(() {
    if(!['day','night_time','clock'].contains(time)) throw const FormatException('배경 시간 선택 오류');
    if(time!='clock' && !ownsAvatar(time)) throw const FormatException('낮·밤 고정은 사야 쓸 수 있어요.');
    state.sceneTime=time;
  });
  Future<bool> claimMission(String scope,String goal,{String? expectedPeriod})=>command(() {
    state.missions=state.missions.observe(now(),autoPeak:autoRate);
    if(expectedPeriod!=null && expectedPeriod!=(scope=='daily' ? state.missions.day:state.missions.week)) throw const FormatException('미션 기간이 바뀌었어요. 다시 확인해 주세요.');
    // 5차 피드백 13: each daily mission pays 붕어빵력 at once; all four
    // together and the weekly ones ask the server for gold.
    final buns=missionBuns(config,tapRate:tapRate,autoRate:autoRate);
    state.missions=state.missions.claim(config,scope,goal,buns:buns);
    final key=state.missions.claimKey(scope,goal),record=state.missions.claims[key]!;
    if(claimGold(record)>0) {
      state.pendingGold['mission:$key']=record;
    } else {
      final paid=DevelopmentBalance.decimal(jsonDecode(record) as Map<String,dynamic>,'buns');
      state.buns+=paid;state.lifetime+=paid;
    }
  });
  /// What [goal] in [scope] pays when claimed now: gold (server-checked), or
  /// 붕어빵력 at once (each daily mission, 5차 피드백 13). For the '오늘' card.
  ({int gold, BigInt buns}) missionReward(String scope,String goal) {
    final gold=missionGold(config,scope,goal);
    return (gold:gold,buns:gold>0 ? BigInt.zero : missionBuns(config,tapRate:tapRate,autoRate:autoRate));
  }
  bool ownsAvatar(String id) => state.hasAvatar(config.section('avatar_catalog'),id);
  /// The first run's 여자/남자 사장님 choice (3차 피드백 H11): that one is
  /// this shop's for good and worn now; the other is bought in 꾸미기.
  /// Only the first-run screen calls this ([OwnerAccount.chooseCharacter]).
  Future<bool> chooseStarterCharacter(String id) => command(() {
    final entry=config.section('avatar_catalog')[id];
    if (entry is! Map<String,dynamic> || entry['slot']!=CosmeticSlot.character.name) throw const FormatException('사장님을 골라 주세요.');
    state.avatarGrants.removeWhere((g)=>(config.section('avatar_catalog')[g] as Map)['slot']==CosmeticSlot.character.name);
    state.avatarGrants.add(id);
    state._wearCharacter(id);
  });
  Future<bool> equipAvatar(String id) => command(() {
    final entry=config.section('avatar_catalog')[id];
    if (entry is! Map<String,dynamic> || !ownsAvatar(id)) throw const FormatException('보유한 아바타 아이템을 골라 주세요.');
    if (entry['slot']==CosmeticSlot.character.name) {
      state._wearCharacter(id);
    } else {
      // 26번 3차 AV3 (DEC-TBD-hAV3-3): the high ponytail and a hat over the
      // crown do not go together; what is worn stays.
      final hair=state.avatarEquipment[CosmeticSlot.hair.name],hat=state.avatarEquipment[CosmeticSlot.hat.name];
      if (entry['slot']==CosmeticSlot.hat.name && hair!=null && hairHatClash(hair,id)) throw const FormatException(hatOverHairText);
      if (entry['slot']==CosmeticSlot.hair.name && hat!=null && hairHatClash(id,hat)) throw const FormatException(hairUnderHatText);
      state.avatarEquipment[entry['slot'] as String]=id;
    }
  });
  Future<bool> _bindRewardAccount(WorkshopOnline gateway,String account) async => command(() {
    if (gateway.authenticatedAccount!=account || account.isEmpty ||
        (state.rewardAccount!=null && state.rewardAccount!=account) ||
        (state.purchases.account!=null && state.purchases.account!=account)) throw const FormatException('원래 진행 계정으로 확인해 주세요.');
    state.rewardAccount=account;
  });
  Future<bool> syncRewards() async {
    final gateway=onlineGateway;
    if (gateway==null || _rewardBusy || disposed || error!=null) return false;
    _rewardBusy=true;
    try {
      final account=gateway.authenticatedAccount;
      await gateway.requireActiveProgress(state.grid.runId);
      if (!await _bindRewardAccount(gateway,account)) return false;
      var count=0;
      for (final key in state.pendingGold.keys.toList()..sort()) {
        final old=state.rewardReceipts[key];
        if (old!=null && (jsonDecode(old) as Map)['outcome']!='pending') continue;
        if (++count>DevelopmentBalance.integer(config.section('pending_reward_sync'),'batch_size')) break;
        final sale=key.startsWith('sale:'),claim=sale ? key.substring(5) : '${state.grid.runId}:$key';
        final payload=jsonDecode(state.pendingGold[key]!) as Map<String,dynamic>;
        final result=await gateway.reward(claim,sale ? 'sale':'mission',payload);
        if (!await command(() {
          if (gateway.authenticatedAccount!=account) throw const FormatException('계정이 변경됐어요.');
          final checked=validateWorkshopRewardReceipt(result,account:account,progress:state.grid.runId,
            claim:claim,kind:sale ? 'sale':'mission',payload:payload);
          final oldRaw=state.rewardReceipts[key];
          if (oldRaw!=null && (jsonDecode(oldRaw) as Map)['outcome']!='pending' && oldRaw!=jsonEncode(checked)) throw const FormatException('확정 보상 수신 충돌');
          state.rewardReceipts[key]=jsonEncode(checked);
        })) return false;
      }
      return true;
    } catch (e) { notice='보상 확인 대기를 유지했어요: $e';return false;
    } finally { _rewardBusy=false;if(!disposed) _notifyChanged(); }
  }
  Future<bool> showRewardedAd(WorkshopAdDriver driver) async {
    final gateway=onlineGateway;
    if (gateway==null || !driver.ready || _adBusy || disposed || error!=null || gameplayPaused) return false;
    _adBusy=true;
    try {
      final account=gateway.authenticatedAccount;
      await gateway.requireActiveProgress(state.grid.runId);
      if (!await _bindRewardAccount(gateway,account)) return false;
      final id=_id();
      // Persist the ID before reserving a server slot. A failed response is
      // recovered by the same ID and never replayed through the SDK.
      if (!await command(() => state.adAttempts[id]={'account':account,'attempt':id,'status':'unknown'})) return false;
      final approval=validateWorkshopAd(await gateway.startAd(id),account,id);
      if (gateway.authenticatedAccount!=account || approval['status']!='reserved' || approval['customData'] is! String) return false;
      if (!await command(() => state.adAttempts[id]=approval)) return false;
      setAdPaused(true);
      try { await driver.show(customData:approval['customData'] as String); }
      finally { setAdPaused(false); }
      return await _queryAd(gateway,account,id);
    } catch (e) { notice='광고 검증 대기를 유지했어요: $e';return false;
    } finally { setAdPaused(false);_adBusy=false;if(!disposed) _notifyChanged(); }
  }
  Future<bool> _queryAd(WorkshopOnline gateway,String account,String id) async {
    final result=validateWorkshopAd(await gateway.queryAd(id),account,id);
    if (gateway.authenticatedAccount!=account) return false;
    return command(() {
      final old=state.adAttempts[id]!;
      if (old['paid']==true && (result['paid']!=true || old['receiptId']!=result['receiptId'] || old['providerProofKey']!=result['providerProofKey'])) throw const FormatException('광고 지급 결과 역행');
      if ((old['status']=='verified' && result['status']!='verified') ||
          (old['status']=='verifying' && result['status']=='reserved') ||
          (old['status']=='rejectedFinal' && result['status']!='rejectedFinal')) throw const FormatException('광고 검증 상태 역행');
      if (old['status']!='unknown' && result['status']!='unknown' &&
          (old['day']!=result['day'] || old['revision']!=result['revision'] || old['gold']!=result['gold'])) throw const FormatException('광고 승인 근거 충돌');
      if (result['status']!='unknown') state.adAttempts[id]=result;
    });
  }
  Future<bool> recoverAds() async {
    final gateway=onlineGateway;
    if (gateway==null || _adBusy || disposed || error!=null) return false;
    _adBusy=true;
    try {
      final account=gateway.authenticatedAccount;
      await gateway.requireActiveProgress(state.grid.runId);
      if (!await _bindRewardAccount(gateway,account)) return false;
      for (final e in state.adAttempts.entries.toList()) {
        if (e.value['paid']==true || e.value['status']=='rejectedFinal') continue;
        if (!await _queryAd(gateway,account,e.key)) return false;
      }
      return true;
    } catch(e) { notice='광고 복구 확인이 필요해요: $e';return false;
    } finally { _adBusy=false;if(!disposed) _notifyChanged(); }
  }
  /// Pause gameplay clocks for an approved ad without pausing economy time.
  void setAdPaused(bool value) {
    if (disposed || value == _adPaused) return;
    _flushActive(); _adPaused = value; _notifyChanged();
  }
  Future<bool> purchaseSkill(WorkshopPurchaseGateway gateway, String skill, {int quantity = 1}) async {
    if (_purchaseBusy || error != null || disposed) return false;
    _purchaseBusy = true;
    try {
      final account = gateway.authenticatedAccount;
      if (account.isEmpty) {
        // Signed out is not a stuck purchase: say plainly that login is needed.
        notice = WorkshopController._buysGoods(skill) ? '카카오 로그인 후 살 수 있어요.' : '카카오 로그인 후 레벨업할 수 있어요.';
        return false;
      }
      if (state.rewardAccount != null && state.rewardAccount != account) throw const FormatException('원래 보상 계정으로 확인해 주세요.');
      await gateway.requireActiveProgress(state.grid.runId);
      if (disposed || gateway.authenticatedAccount != account) return false;
      final quote = quoteWorkshopProduct(config, skill, owned: state.purchases.owned[skill] ?? 0, quantity: quantity);
      final intent = PurchaseJournal.start(account, _id(), quote);
      if (!await command(() => state.purchases = state.purchases.prepare(config, intent,
          buns: state.buns, lifetime: state.lifetime,level:state.level))) return false;
      final response = await gateway.reserve(intent);
      if (!await _purchaseResponse(gateway, account, intent.transactionId, response)) return false;
      return await _finishPurchase(gateway, account, intent.transactionId);
    } catch (e) {
      notice = '${WorkshopController._buysGoods(skill) ? '구매' : '레벨업'} 확인이 남아 있어요. 새 거래 대신 같은 기록을 복구해 주세요: $e';
      return false;
    } finally { _purchaseBusy = false; if (!disposed) _notifyChanged(); }
  }
  Future<bool> recoverPurchase(WorkshopPurchaseGateway gateway, String transaction, {bool cancel = false}) async {
    if (_purchaseBusy || error != null || disposed) return false;
    _purchaseBusy = true;
    try {
      final account = gateway.authenticatedAccount;
      final saved = state.purchases.journal(transaction);
      if (account != saved.accountId) throw const FormatException('원래 구매 계정으로 확인해 주세요.');
      await gateway.requireActiveProgress(state.grid.runId);
      if (disposed || gateway.authenticatedAccount != account) return false;
      var response = await gateway.query(account, transaction);
      if (response['status'] == 'unknown' && !cancel) response = await gateway.reserve(saved);
      if (!await _purchaseResponse(gateway, account, transaction, response)) return false;
      if (cancel && !state.purchases.journal(transaction).settled) {
        response = await gateway.cancel(account, transaction);
        if (!await _purchaseResponse(gateway, account, transaction, response)) return false;
        if (state.purchases.journal(transaction).serverStatus == 'reserved') return false;
      }
      return await _finishPurchase(gateway, account, transaction);
    } catch (e) {
      final cosmetic = WorkshopController._buysGoods(state.purchases.journals[transaction]?.quote.skillId ?? '');
      notice = '${cosmetic ? '구매' : '레벨업'} 복구 확인이 필요해요: $e'; return false;
    } finally { _purchaseBusy = false; if (!disposed) _notifyChanged(); }
  }
  Future<bool> _purchaseResponse(WorkshopPurchaseGateway gateway, String account, String transaction,
      Map<String, dynamic> response) async {
    if (disposed || gateway.authenticatedAccount != account) return false;
    return command(() => state.purchases = state.purchases.response(transaction, response));
  }
  Future<bool> _finishPurchase(WorkshopPurchaseGateway gateway, String account, String transaction) async {
    var journal = state.purchases.journal(transaction);
    if (journal.serverStatus == 'reserved') {
      if (!await command(() {
        final result = state.purchases.debit(transaction, state.buns);
        state.purchases = result.purchases; state.buns = result.buns;
      })) return false;
      journal = state.purchases.journal(transaction);
      final response = await gateway.commit(journal);
      if (!await _purchaseResponse(gateway, account, transaction, response)) return false;
    }
    journal = state.purchases.journal(transaction);
    if (journal.serverStatus == 'unknown' || journal.serverStatus == 'reserved') return false;
    return command(() {
      final previous=state.purchases.journal(transaction);
      final result = state.purchases.settle(transaction, state.buns);
      state.purchases = result.purchases; state.buns = result.buns;
      final current=state.purchases.journal(transaction);
      if(!previous.applied && current.applied && !current.quote.skillId.contains(':')) {
        state.missions=state.missions.observe(now(),purchases:current.quote.quantity,autoPeak:autoRate);
      }
      // 재료 타이쿤 C: the special ingredients bought arrive with the purchase.
      if(!previous.applied && current.applied && current.quote.skillId.startsWith('ingredient:')) {
        state.pantry.buyPremium(pantryConfig,current.quote.skillId.substring(11),current.quote.quantity,state.level);
      }
    });
  }
}
