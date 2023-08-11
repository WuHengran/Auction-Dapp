<template>
  <div class="flex-col page" v-loading="loading" element-loading-text="Please wait for the createAuction execution to complete">
    <div class="flex-col justify-start items-start self-start text-wrapper">
      <!-- <span class="text">EnglishAuction</span> -->
      <select class="text" v-model="selectedAuction" @change="onChangeSelectedAuction">
        <option value="EnglishAuction">English Auction</option>
        <option value="DutchAuction">Dutch Auction</option>
      </select>
    </div>
    <select style="width: 100%;" class="self-start font_1 text_2" v-if="accounts.length > 0" v-model="selectedAccount">
      <option v-for="(account, index) in accounts" :key="account" :value="account">
        {{ account }}
      </option>
    </select>
    <div v-else>
      Loading accounts...
    </div>
    <!-- <span class="self-start font_1 text_2">user</span> -->
    <div class="flex-col group">
      <input v-model="nftId" id="nftId" style="padding-left: 13px;"
        class="flex-col justify-start items-start text-wrapper_2 view" placeholder="nftId" />
      <input v-model="startPrice" id="startPrice" style="padding-left: 13px;"
        class="flex-col justify-start items-start text-wrapper_2" placeholder="startPrice" />
      <input v-model="endPrice" id="endPrice" style="padding-left: 13px;" v-if="selectedAuction === 'DutchAuction'"
        class="flex-col justify-start items-start text-wrapper_3" placeholder="endPrice" />
      <input v-model="duration" id="duration" style="padding-left: 13px;" v-if="selectedAuction === 'DutchAuction'"
        class="flex-col justify-start items-start text-wrapper_2" placeholder="duration" />
      <input v-model="title" id="title" style="padding-left: 13px;"
        class="flex-col justify-start items-start text-wrapper_2" placeholder="title" />
      <input v-model="description" id="description" style="padding-left: 13px;"
        class="flex-col justify-start items-start text-wrapper_4" placeholder="description" />
      <div @click="onCreate" class="flex-col justify-start items-center self-start button" placeholder="Create"><span
          class="font_2">Create</span></div>
    </div>
    <div v-for="(bid, index) in bids" :key="index" class="flex-col section space-y-9">
      <span class="self-start text_6">Title: {{ bid.title }}</span>
      <div class="flex-row justify-between">
        <span class="font_3">price: {{ bid.price }}</span>
        <span class="font_3 text_7">isEnd: {{ bid.isEnd }}</span>
      </div>
      <span style="width: 100%;" class="self-start font_3">owner: {{ bid.ower }}</span>
      <span style="width: 100%;" class="self-start font_3">seller: {{ bid.seller }}</span>
      <span class="self-start font_3">description: {{ bid.description }}</span>
      <div class="flex-row group_2">
        <input v-model="bidValues[index]" style="padding-left: 13px;" class="flex-auto button_2" />
        <div @click="onBid(index, bidValues[index])" class="flex-col justify-start items-center shrink-0 button_3">
          <span class="font_2">Bid</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import Web3, { net } from 'web3';
import { ethers } from "ethers";

import {
  erc165ABI, DutchFactoryABI, EnglishFactoryABI, EnglishAuctionABI, DutchAuctionABI,
  erc165Address, DutchFactoryAddress, EnglishFactoryAddress
} from '@/contractInfo.js';

export default {
  components: {},
  data() {
    return {
      provider: null, // Provider 实例
      accounts: [], // BC 账号列表
      selectedAccount: '', // 选中的账号地址
      selectedAuction: 'EnglishAuction', // 默认选择为 EnglishAuction
      nftId: null,
      startPrice: null,
      endPrice: null,
      duration: null,
      title: '',
      description: '',
      bidValues: [],
      bids: [],
      overrides: {
        gasLimit: 5000000,
        gasPrice: ethers.utils.parseUnits('6', 'gwei')
      },
      loading: false,
    };
  },
  mounted() { },
  async created() {
    await this.initWeb3();
    await this.refreshList();
  },
  methods: {
    async onCreate() {
      try {
        // 载入合约
        const erc165 = new ethers.Contract(erc165Address, erc165ABI, this.provider.getSigner());
        const englishFactory = new ethers.Contract(EnglishFactoryAddress, EnglishFactoryABI, this.provider.getSigner());
        const dutchFactory = new ethers.Contract(DutchFactoryAddress, DutchFactoryABI, this.provider.getSigner());

        if (this.selectedAuction === 'EnglishAuction') {
          // 1.调用NFT合约的mine方法创建藏品
          await erc165.mint(this.selectedAccount, this.nftId, this.overrides);

          // 2.调用工厂合约创建拍卖，并通过getAuction获取该拍卖的地址
          await englishFactory.createAuction(erc165Address, this.nftId, this.startPrice, this.title, this.description, this.overrides);
          console.log('createAuction');

          this.loading = true;
          englishFactory.on("AuctionCreated", async (nftId, newAuctionAddress, auctionsLength) => {
            this.loading = false;

            console.log(nftId, newAuctionAddress, auctionsLength);

            const auctions = await englishFactory.getAuctions();
            console.log(auctions);

            const auctionAddress = auctions[auctions.length - 1];
            console.log(auctionAddress);

            // 3.调用NFT合约的approve方法授予权限
            await erc165.approve(auctionAddress, this.nftId, this.overrides);

            // 4.调用Auction合约开始拍卖
            const englishAuction = new ethers.Contract(auctionAddress, EnglishAuctionABI, this.provider.getSigner());
            await englishAuction.start(this.overrides);

            this.$notify({
              message: 'success',
              type: 'success'
            });

            this.refreshList();
          });
        } else {
          // 1.调用NFT合约的mine方法创建藏品
          await erc165.mint(this.selectedAccount, this.nftId, this.overrides);

          // 2.调用工厂合约创建拍卖，并通过getAuction获取该拍卖的地址
          await dutchFactory.createAuction(erc165Address, this.nftId, this.startPrice, this.endPrice, this.duration, this.title, this.description, this.overrides);

          this.loading = true;
          dutchFactory.on("AuctionCreated", async (nftId, newAuctionAddress, auctionsLength) => {
            this.loading = false;

            console.log(nftId, newAuctionAddress, auctionsLength);

            const auctions = await dutchFactory.getAuctions();
            console.log('auctions: ' + auctions);

            const auctionAddress = auctions[auctions.length - 1];
            console.log('auctionAddress: ' + auctionAddress);

            // 3.调用NFT合约的approve方法授予权限
            await erc165.approve(auctionAddress, this.nftId, this.overrides);

            // 4.调用Auction合约开始拍卖
            const dutchAuction = new ethers.Contract(auctionAddress, DutchAuctionABI, this.provider.getSigner());
            await dutchAuction.start(this.overrides);

            this.$notify({
              message: 'success',
              type: 'success'
            });

            this.refreshList();
          });
        }
      } catch (error) {
        this.$notify({
          message: error,
          type: 'error'
        });
      }
    },
    async initWeb3() {
      if (typeof window.ethereum == 'undefined') {
        alert('Please install metamask or open the page in the dapp environment');
      }

      window.ethereum.on('accountsChanged', () => {
        window.location.reload();
      })

      window.ethereum.on('chainChanged', () => {
        window.location.reload()
      })

      this.provider = new ethers.providers.Web3Provider(window.ethereum);
      const network = await this.provider.getNetwork();
      if (network.name !== "sepolia") {
        alert('Please switch to sepolia network');
        return;
      }

      await window.ethereum.enable();

      this.accounts = await ethereum.request({ method: 'eth_requestAccounts' })
      console.log(this.accounts);

      if (this.accounts.length > 0) {
        this.selectedAccount = this.accounts[0];
      }
    },
    async refreshList() {
      const englishFactory = new ethers.Contract(EnglishFactoryAddress, EnglishFactoryABI, this.provider.getSigner());
      const dutchFactory = new ethers.Contract(DutchFactoryAddress, DutchFactoryABI, this.provider.getSigner());
      const bids = [];

      if (this.selectedAuction === 'EnglishAuction') {
        // 1.获取所有Address
        const auctions = await englishFactory.getAuctions();
        for (let i = 0; i < auctions.length; i++) {
          const address = auctions[i];
          // 2.构造Auction合约并建立连接
          const englishAuction = new ethers.Contract(address, EnglishAuctionABI, this.provider.getSigner());
          bids.push({
            address: await address,
            title: await englishAuction.title(),
            price: await englishAuction.highestBid(),
            isEnd: await englishAuction.ended(),
            ower: await englishAuction.highestBidder(),
            seller: await englishAuction.seller(),
            description: await englishAuction.description(),
          })
          console.log(bids);
        }
      } else {
        const auctions = await dutchFactory.getAuctions();
        for (let i = 0; i < auctions.length; i++) {
          const address = auctions[i];
          const dutchAuction = new ethers.Contract(address, DutchAuctionABI, this.provider.getSigner());
          bids.push({
            address: await address,
            title: await dutchAuction.title(),
            price: await dutchAuction.highestBid(),
            isEnd: await dutchAuction.ended(),
            ower: await dutchAuction.highestBidder(),
            seller: await dutchAuction.seller(),
            description: await dutchAuction.description(),
          })
        }
      }
      this.bids = bids;
      console.log(bids);
    },
    async onBid(index, val) {
      console.log(val);
      if (this.selectedAuction === 'EnglishAuction') {
        const englishAuction = new ethers.Contract(this.bids[index].address, EnglishAuctionABI, this.provider.getSigner());
        await englishAuction.bid({
          value: val,
          gasLimit: 5000000,
          gasPrice: ethers.utils.parseUnits('6', 'gwei')
        });
      } else {
        const dutchAuction = new ethers.Contract(this.bids[index].address, DutchAuctionABI, this.provider.getSigner());
        await dutchAuction.bid({
          value: val,
          gasLimit: 5000000,
          gasPrice: ethers.utils.parseUnits('6', 'gwei')
        });
      }
      this.refreshList();
    },
    onChangeSelectedAuction() {
      this.refreshList();
      this.bidValues = [];
    }
  },
};
</script>

<style scoped lang="css">
.page {
  padding: 0.69rem 1.13rem 8.5rem;
  background-color: #ffffff;
  width: 100%;
  overflow-y: auto;
  overflow-x: hidden;
  height: 100%;
}

.text-wrapper {
  padding: 0.38rem 0;
  background-color: #ffffff;
  border: solid 0.063rem #ffffff;
}

.text {
  color: #000000;
  font-size: 1.25rem;
  font-family: 'Heiti SC';
  font-weight: 700;
  line-height: 1.25rem;
}

.font_1 {
  font-size: 0.94rem;
  font-family: 'Heiti SC';
  line-height: 0.94rem;
  font-weight: 700;
  color: #b1b1b1;
}

.text_2 {
  margin-top: 0.44rem;
  color: #000000;
}

.group {
  margin-top: 1rem;
  padding: 1rem 0 0.63rem;
  border-top: solid 0.063rem #000000;
  border-bottom: solid 0.063rem #000000;
}

.text-wrapper_2 {
  margin-top: 0.31rem;
  padding: 0.63rem 0;
  border-radius: 0.5rem;
  border: solid 0.063rem #979797;
}

.view {
  margin-top: 0;
}

.text_3 {
  margin-left: 0.75rem;
}

.text-wrapper_3 {
  margin-top: 0.31rem;
  padding: 0.63rem 0 0.5rem;
  border-radius: 0.5rem;
  border: solid 0.063rem #979797;
}

.text_4 {
  margin-left: 0.75rem;
}

.text-wrapper_4 {
  margin-top: 0.31rem;
  padding: 0.5rem 0 5.75rem;
  border-radius: 0.5rem;
  border: solid 0.063rem #979797;
}

.text_5 {
  margin-left: 0.5rem;
}

.button {
  margin-top: 0.75rem;
  padding: 0.75rem 0;
  background-color: #027afd;
  width: 6.69rem;
}

.font_2 {
  font-size: 0.94rem;
  font-family: 'Heiti SC';
  line-height: 0.94rem;
  font-weight: 700;
  color: #ffffff;
}

.section {
  margin-top: 1.06rem;
  padding: 0.88rem 0.63rem 0;
  border-radius: 0.5rem;
  border: solid 0.063rem #000000;
}

.space-y-9>*:not(:first-child) {
  margin-top: 0.56rem;
}

.text_6 {
  color: #000000;
  font-size: 1.06rem;
  font-family: 'Heiti SC';
  font-weight: 700;
  line-height: 1.06rem;
}

.font_3 {
  font-size: 0.94rem;
  font-family: 'Heiti SC';
  line-height: 0.94rem;
  font-weight: 700;
  color: #b8b8b8;
}

.text_7 {
  margin-right: 0.38rem;
}

.group_2 {
  padding: 0.75rem 0 0.63rem;
  border-top: solid 0.063rem #979797;
}

.button_2 {
  background-color: #ffffff;
  border-radius: 0.5rem 0px 0px 0.5rem;
  width: 14.06rem;
  height: 2.44rem;
  border: solid 0.063rem #000000;
}

.button_3 {
  margin-right: 0.38rem;
  padding: 0.75rem 0;
  background-color: #027afd;
  border-radius: 0px 0.5rem 0.5rem 0px;
  width: 6.13rem;
  height: 2.44rem;
}
</style>
