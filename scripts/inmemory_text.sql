drop table inm_text;

create table inm_text (id integer GENERATED ALWAYS AS IDENTITY primary key, payload json);

insert into inm_text(payload)
    select json_object(*) payload from all_tables
    ;
insert into inm_text(payload)
    select json_object(*) payload from all_objects
;

select payload from INM_TEXT;

select payload from inm_text where json_textcontains(payload, '$.INMEMORY', 'YES');

alter table inm_text inmemory priority critical inmemory text(
    payload
);  
