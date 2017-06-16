	#join global_pars_num gpn on gpn.par_type_id = pt.par_type_id
	#where name like "r%" group by name;
select count(*) from blocks;
select * from global_pars_num ;
    
select b.block_id, ptc.name, gpc.value, ptn.name, gpn.value from blocks b, pars_types ptc, pars_types ptn, global_pars_num gpn, global_pars_char gpc 
where gpn.par_type_id = ptn.par_type_id and gpc.par_type_id = ptc.par_type_id 
and b.block_id = gpc.node_id and b.block_id = gpn.node_id and gpn.level = 2
and gpc.level = 2;

select b.block_id, pt.name, gp.value from blocks b, pars_types pt, global_pars_num gp
where gp.par_type_id = pt.par_type_id 
and b.block_id = gp.node_id and gp.level = 2
union
select b.block_id, pt.name, gp.value from blocks b, pars_types pt, global_pars_char gp
where gp.par_type_id = pt.par_type_id 
and b.block_id = gp.node_id and gp.level = 2;