# HIT
The HIT is another token system as an infrastructure in Metaverse.
FOR Market and Token Dept. - exchange for all NFTables.

We need a mechanism and instrument in chain world, the Human Individual Token (HIT) is made for the exchange and value-store in chain world. 
Possibly it is the infrastructure modeling for the Metaverse.
The number 0 token is the HIT (Human Individual Token), with unit as Hayek. 1HIT=10e18Hayet (unit of Ght = 10e9Hayet), the supply fixed as 1 billion HIT .


#Starter
Raising money:
Use ETH wallets such as MetaMask to transfer to the contract address, 0.025ETH for 1HIT in coming 100 days.
ETH: 0xee3d8dFe01180ba60fa4a32193AeEdf167a6F49E

#Using HIT:
You can implement wallet,web page or command to make your token and tranfer them freely, also you can build your applications on them.
The APIs are as following.TBD
Before usage of HIT, please have a plan about Token Name, Purpose, Circulations, Wallet Address etc.

#HIT API:
1. mintMine(string memory strname,uint256 _a, string memory _uri) public returns(uint256)
	Mint your token, mintMine("your_token_name", "amount","Icon_URL" )
	each address can only mint once
	amount should be less than 1**10 
	
2. tokenId()
	Query the tokenId of your current address

3. payByMyToken(address dest, uint256 _amount, string memory notes) 
	Pay to another address IN YOUR Token.
	amount should be less than you have mint.
	notes can be the leaving message for this payment.
	e.g. payByMyToken(0x5cE1DC0983923894E9dE1D60d01670935D2662E3, 2900, "Testing") 

4. payByHIT(address dest, uint256 _amount, string memory notes) 
	same as above, but via HIT.

5. payByOtherToken(address dest, uint256 _tid,uint256 _amount, string memory notes)
	same as above, but via OtherToken id, which should be known and exists.

	
6. myTokenBalance() : Query your balance of your token id.
7. myTokenById(tid)() : Query your balance of another id (Your Holdings of others).
8. myTokenOfHIT(): Query your balance of HIT.
9. myAssetsInHIT() : Query your assets in scale of HITs. 
