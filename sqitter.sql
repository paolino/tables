CREATE TABLE utenti ( 
    utente         INTEGER PRIMARY KEY NOT NULL,
    nominativo     TEXT    NOT NULL UNIQUE
    );

CREATE TABLE eventi ( 
    evento      integer PRIMARY KEY not null,
    titolo      TEXT not null unique,
    data        TEXT    NOT NULL
                     DEFAULT (date('now','localtime'))
    );
CREATE TABLE episodi ( 
    episodio      integer PRIMARY KEY not null,
    titolo      TEXT not null unique,
    evento      INTEGER NOT NULL references eventi ON DELETE CASCADE, -- no events no party
    data        TEXT    NOT NULL
                     DEFAULT (date('now','localtime'))
    );

CREATE TABLE stanze ( 
    stanza      integer PRIMARY KEY not null,
    titolo      TEXT not null,
    data        TEXT    NOT NULL
                     DEFAULT (date('now','localtime')),
    padrone     INTEGER NOT NULL references utenti ON DELETE CASCADE, -- a room must have an owner
    unique (titolo,padrone) 

    );


-- all potential partecipations to private rooms. Must be issued from owners
create table partecipazioni (
    partecipazione integer PRIMARY KEY not null,
    utente     INTEGER NOT NULL references utenti ON DELETE CASCADE,
    stanza     INTEGER NOT NULL references stanze ON DELETE CASCADE,
    unique (utente,stanza)
    );


-- active partecipations. Users have selected these partecipations.
create table selezione_partecipazioni (
    partecipazione     INTEGER NOT NULL references partecipazioni ON DELETE CASCADE
    );

-- selected events. All events followed by users now. These have actually been selected or their selection have been deduced
create table selezione_eventi (
    evento_selezionato integer PRIMARY KEY not null,
    evento  INTEGER NOT NULL references eventi ON DELETE CASCADE,
    utente  INTEGER NOT NULL references utenti ON DELETE CASCADE,
    unique (evento,utente) on conflict ignore
    );

-- selected episodes. All episodes followed by users now. selected episodes must refer to selected episodes
create table selezione_episodi (
    evento_selezionato  INTEGER NOT NULL references selezione_eventi ON DELETE CASCADE, -- easy peasy clean
    episodio  INTEGER NOT NULL references episodi ON DELETE CASCADE,
    unique (evento_selezionato,episodio) on conflict ignore
    );

-- controlled insertion into episodes selection
create view insert_selezione_episodi as select episodio,utente,evento from selezione_episodi join selezione_eventi on evento;


-- default to adding an event if one of its episodes are selected and add its reference to the selected episode
create trigger insert_selezione_episodi instead of insert on insert_selezione_episodi begin
                
                insert into selezione_eventi (evento,utente) select evento,new.utente from episodi where episodio = new.episodio;
                insert into selezione_episodi (evento_selezionato, episodio) 
                                select evento_selezionato,evento  from selezione_eventi join episodi where 
                                                selezione_eventi.evento = episodi.evento and episodio = new.episodio ;
	end;

-- care, we don't enforce referential integrity with selections, as shouts persists even after deselection of contexts.

-- but we force selection on insert

create table event_shouts (
        evento  INTEGER NOT NULL references eventi ON DELETE CASCADE,
        utente  INTEGER NOT NULL references utenti ON DELETE CASCADE,
        testo   text not null
        )

create trigger selezione_evento_on_shout after insert on event_shouts begin
        insert into selezione_eventi (evento,utente) select new.evento,new.utente;

create table episode_shouts (
        episodio  INTEGER NOT NULL references episodi ON DELETE CASCADE,
        utente  INTEGER NOT NULL references utenti ON DELETE CASCADE,
        testo   text not null
        )

create trigger selezione_episodio_on_shout after insert on event_shouts begin
        insert into selezione_eventi (evento,utente) values (new.evento,new.utente);
        insert into selezione_episodi (evento_selezionato, episodio) 
                                select evento_selezionato,evento  from selezione_eventi join episodi where 
                                                selezione_eventi.evento = episodi.evento and episodio = new.episodio ;
        end;

/*
CREATE TRIGGER valutazioni after insert on valutazioni begin
    update utenti set punti = round(new.punti,2), valutazione = new.data where utente=new.utente; 
    end;
CREATE VIEW nuovoutente as select utente,colloquio,nominativo,pin,punti,valutazione,residuo from utenti;
CREATE TRIGGER nuovoutente instead of insert on nuovoutente begin
    insert into utenti (utente,colloquio,nominativo,residuo) values (new.utente,new.colloquio,new.nominativo,new.residuo);
    insert into pin (utente,pin) values (new.utente,new.pin);
    insert into valutazioni (utente,punti,data,note) values (new.utente,round(new.punti,2),new.valutazione,'ingresso');
    end;
CREATE TABLE ricariche ( 
    data TEXT NOT NULL
              UNIQUE
              DEFAULT (date('now','localtime'))
    );
CREATE TRIGGER ricarica AFTER INSERT ON ricariche
        BEGIN
            UPDATE utenti
               SET residuo = punti
               where julianday() < julianday (valutazione,'+6 months');
        end;
CREATE TABLE prezzi ( 
    prezzo   DOUBLE  NOT NULL primary key
    );
CREATE TABLE acquisti ( 
    acquisto INTEGER PRIMARY KEY,
    utente  INTEGER NOT NULL
                     REFERENCES utenti ON DELETE CASCADE,
    apertura TEXT    NOT NULL
                     DEFAULT CURRENT_TIMESTAMP
    );
CREATE VIEW nuovoacquisto as select colloquio,utente from utenti;
CREATE TABLE chiusure (
	acquisto integer not null unique references acquisti  ON DELETE CASCADE,
	chiusura NOT NULL
                     DEFAULT CURRENT_TIMESTAMP
	);
CREATE VIEW acquisti_aperti as select acquisto,utente from acquisti where acquisto not in (select acquisto from chiusure);
CREATE TRIGGER doppio_acquisto before insert on acquisti when (new.utente in (select utente from acquisti_aperti)) begin
	select raise(abort,"due acquisti contemporanei per utente");
	end;
CREATE VIEW chiusura as select acquisto,pin from acquisti_aperti join utenti using(utente);
CREATE TRIGGER chiusura_errata instead of insert on chiusura when (new.pin != (select pin from chiusura where acquisto = new.acquisto)) begin
	select raise (abort,"PIN sbagliato");
	end;
CREATE TRIGGER chiusura instead of insert on chiusura when (new.pin == (select pin from chiusura where acquisto = new.acquisto)) begin
	insert into chiusure (acquisto) values (new.acquisto);
	end;
CREATE TABLE amministrazione (login text not null primary key);
CREATE VIEW fallimento as select acquisto from acquisti_aperti;
CREATE TRIGGER recupero_spesa_per_fallimento instead of insert on fallimento begin	
	update utenti set residuo 
		= round(residuo + (
			select case 
				when ((select prezzo from spese where acquisto = new.acquisto) notnull)
					then (select sum(prezzo) from spese where acquisto = new.acquisto) 
					else 0 
				end
			),2)
			where utente =  (select utente from acquisti_aperti where acquisto = new.acquisto);
	delete from spese where acquisto = new.acquisto;
	delete from acquisti where acquisto = new.acquisto;
	end;
CREATE TRIGGER ricaricadoppia before INSERT ON ricariche 
when ((select data from ricariche where date(data,'start of month') = date('now','start of month')) notnull)
        BEGIN select raise(abort,"questo mese la ricarica è già avvenuta"); end;
CREATE TABLE spese ( 
    spesa integer primary key,
    acquisto INTEGER NOT NULL
                     REFERENCES acquisti ON DELETE CASCADE,
    prezzo double NOT NULL,
    prodotto text
);
CREATE VIEW cancella as select acquisto,prezzo,prodotto from spese;
CREATE TRIGGER cancella instead of insert on cancella when ((select spesa from spese where prezzo = new.prezzo and acquisto = new.acquisto and ((prodotto isnull and new.prodotto isnull) or new.prodotto = prodotto)) notnull) begin
delete from spese where  spesa = (select spesa from spese where prezzo = new.prezzo and acquisto = new.acquisto and  ((prodotto isnull and new.prodotto isnull) or new.prodotto = prodotto) limit 1);
 update utenti set residuo = round(residuo + new.prezzo,2) where utente = (select utente from acquisti_aperti where acquisto = new.acquisto);
end;
CREATE TRIGGER acquisto_valido after insert on spese when ((select acquisto from chiusure where acquisto = new.acquisto) notnull) begin
        select raise(abort,"acquisto già chiuso");
        end;
CREATE TRIGGER riduzione_residuo after insert on spese begin
        update utenti set 
                residuo = round(residuo - new.prezzo,2) where utente = (select utente from  acquisti where acquisto = new.acquisto);
end;
CREATE INDEX aquisto_of_spese on spese (acquisto);
CREATE TABLE prodotti (nome text primary key not null, prezzo double not null check (prezzo > 0));
CREATE VIEW scontrino as select acquisti.acquisto ,spese.prezzo,prodotto,count(*) as numero,count(*) * prezzo as valore from acquisti join spese on
(acquisti.acquisto = spese.acquisto) group by spese.prezzo,spese.acquisto,spese.prodotto;
CREATE VIEW totali as SELECT acquisto,utente,sum(valore) as valore,sum (numero) as numero , apertura FROM scontrino join acquisti  using (acquisto) group by acquisto;
CREATE TRIGGER nuovoacquisto instead of insert on nuovoacquisto begin
        select case when ((select utente from utenti where utente = new.utente and colloquio = new.colloquio) isnull) then raise (abort,"utente sconosciuto") end;
        insert into acquisti (utente) values (new.utente);
        end;
create table cassa (
	prodotto text unique references prodotti ON DELETE CASCADE
	);
*/
