-- 旧スキーマのデータ（移行前）
insert into public.members(id,name,slug,unit,ul,role,certified_grade,active) values
 ('00000000-0000-0000-0000-00000000c001','社員 太郎','s1','unitA',null,'ul',null,true),
 ('00000000-0000-0000-0000-00000000c002','エグゼ 花子','s2','unitB','社員 太郎','ul',9,true),
 ('00000000-0000-0000-0000-00000000c003','育成 次郎','s3',null,null,'mentor',null,true),
 ('00000000-0000-0000-0000-00000000c004','新人 一郎','s4','unitA','社員　太郎','member',null,true),
 ('00000000-0000-0000-0000-00000000c005','中堅 三郎','s5','unitB','エグゼ花子','member',3,true),
 ('00000000-0000-0000-0000-00000000c006','チェックだけ ULさん','s6','unitC',null,'ul',null,true);
insert into public.progress(member_id,item_id) values ('00000000-0000-0000-0000-00000000c006','g1.1-1');
