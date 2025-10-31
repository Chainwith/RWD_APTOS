module rewardy_coin_factory_address::coin_factory {
    use std::error;
    use std::signer;
    use std::string::{Self, utf8};
    use std::option;

    use aptos_framework::fungible_asset::{
        Self,
        MintRef,
        TransferRef,
        BurnRef,
        Metadata,
        FungibleAsset
    };
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::function_info;
    use aptos_framework::dispatchable_fungible_asset;

    const E_NOT_OWNER: u64 = 1;
    const E_PAUSED: u64 = 2;
    const E_SAME_VALUE: u64 = 3;
    const ASSET_SYMBOL: vector<u8> = b"RWD";
    const ASSET_NAME: vector<u8> = b"Rewardy";

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct RewardyCoin has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
        extend_ref: ExtendRef,
        paused: bool
    }

    fun init_module(sender: &signer) {
        assert!(
            @rewardy_coin_factory_address == signer::address_of(sender),
            error::permission_denied(E_NOT_OWNER)
        );

        let constructor_ref = &object::create_named_object(sender, ASSET_SYMBOL);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::some<u128>(3000000000000000000),
            utf8(ASSET_NAME),
            utf8(ASSET_SYMBOL),
            8,
            utf8(
                b"https://rewardy.s3.ap-northeast-2.amazonaws.com/Rewardy+Coin/front_rwd.png"
            ), 
            utf8(b"https://www.rewardywallet.com/") 
        );

        let extend_ref = object::generate_extend_ref(constructor_ref);
        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
        let metadata_object_signer = object::generate_signer(constructor_ref);

        move_to(
            &metadata_object_signer,
            RewardyCoin { mint_ref, transfer_ref, burn_ref, paused: false, extend_ref }
        );

        let deposit =
            function_info::new_function_info(
                sender,
                string::utf8(b"coin_factory"),
                string::utf8(b"deposit")
            );
        let withdraw =
            function_info::new_function_info(
                sender,
                string::utf8(b"coin_factory"),
                string::utf8(b"withdraw")
            );
        dispatchable_fungible_asset::register_dispatch_functions(
            constructor_ref,
            option::some(withdraw),
            option::some(deposit),
            option::none()
        );
    }

    #[view]
    public fun coin_address(): address {
        object::create_object_address(&@rewardy_coin_factory_address, ASSET_SYMBOL)
    }

    fun get_metadata(): Object<Metadata> {
        let asset_address =
            object::create_object_address(&@rewardy_coin_factory_address, ASSET_SYMBOL);
        object::address_to_object<Metadata>(asset_address)
    }

    public entry fun set_puased(owner: &signer, paused: bool) acquires RewardyCoin {
        let asset = get_metadata();
        authorized_borrow_refs(owner, asset);

        let managed_fungible_asset =
            borrow_global_mut<RewardyCoin>(object::object_address(&asset));
        assert!(
            managed_fungible_asset.paused != paused, error::unavailable(E_SAME_VALUE)
        );
        managed_fungible_asset.paused = paused;
    }

    inline fun not_paused() acquires RewardyCoin {
        let asset = get_metadata();
        let managed_fungible_asset =
            borrow_global<RewardyCoin>(object::object_address(&asset));
        assert!(!managed_fungible_asset.paused, error::unavailable(E_PAUSED));
    }

    inline fun authorized_borrow_refs(
        owner: &signer, asset: Object<Metadata>
    ): &RewardyCoin acquires RewardyCoin {
        assert!(
            object::root_owner(asset) == signer::address_of(owner),
            error::permission_denied(E_NOT_OWNER)
        );
        borrow_global<RewardyCoin>(object::object_address(&asset))
    }

    public entry fun mint(owner: &signer, to: address, amount: u64) acquires RewardyCoin {
        not_paused();
        let asset = get_metadata();
        let managed_fungible_asset = authorized_borrow_refs(owner, asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        let fa = fungible_asset::mint(&managed_fungible_asset.mint_ref, amount);
        fungible_asset::deposit_with_ref(
            &managed_fungible_asset.transfer_ref, to_wallet, fa
        );
    }

    public entry fun burn(owner: &signer, from: address, amount: u64) acquires RewardyCoin {
        not_paused();
        let asset = get_metadata();
        let burn_ref = &authorized_borrow_refs(owner, asset).burn_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        fungible_asset::burn_from(burn_ref, from_wallet, amount);
    }

    public fun deposit<T: key>(
        store: Object<T>,
        fa: FungibleAsset,
        transfer_ref: &TransferRef
    ) acquires RewardyCoin {
        not_paused();
        fungible_asset::deposit_with_ref(transfer_ref, store, fa);
    }

    public fun withdraw<T: key>(
        store: Object<T>,
        amount: u64,
        transfer_ref: &TransferRef
    ): FungibleAsset acquires RewardyCoin {
        not_paused();
        fungible_asset::withdraw_with_ref(transfer_ref, store, amount)
    }

    public entry fun change_owner(owner: &signer, new_owner: address) {
        object::transfer_raw(owner, @rewardy_coin_factory_address, new_owner);
    }
}
