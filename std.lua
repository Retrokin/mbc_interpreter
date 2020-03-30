local std={
	function(rnr,t,id)			--debugprint
		local tv,tks=rnr:getkey(t,id)
		printh("table[" .. tv .. "][" .. tks .. "]=" .. rnr.var[tv][tks])
	end,
	function(rnr,t,id,s)			--luaname
		local tv,tks=rnr:getkey(t,id)
		rnr[tv][tks]=tks .. "_" .. s
	end
}