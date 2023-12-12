SELECT * FROM employee;
--EASY QUERIES

--1. Who is the senior most employee based on job title?

SELECT * FROM employee ORDER BY levels DESC LIMIT 1;

--2. Which countries have the most invoices?

SELECT COUNT(*) AS c,billing_country FROM invoice 
group by billing_country order by c DESC;

--3. What are top 3 values of total invoice?

SELECT total FROM invoice order by total desc limit 3;

--4. Which city has the best customers? We would like to throw a promotional Music 
--Festival in the city we made the most money. Write a query that returns one city that 
--has the highest sum of invoice totals. Return both the city name & sum of all invoice 
--totals

SELECT billing_city, SUM(total) as invoice_total from invoice group by billing_city order by invoice_total desc LIMIT 1;

--5. Who is the best customer? The customer who has spent the most money will be 
--declared the best customer. Write a query that returns the person who has spent the 
--most money

SELECT c.customer_id,c.first_name,c.last_name, SUM(i.total) as cinvoice_total from invoice as i join customer as c ON i.customer_id=c.customer_id group by c.customer_id order by cinvoice_total desc LIMIT 1;

--MODERATE QUERIES

--1. Write query to return the email, first name, last name, & Genre of all Rock Music 
--listeners. Return your list ordered alphabetically by email starting with A

SELECT DISTINCT email,first_name,last_name 
FROM customer as c
join invoice as i ON c.customer_id = i.invoice_id
join invoice_line as il ON i.invoice_id = il.invoice_id
WHERE track_id IN(
	SELECT track_id FROM track
	JOIN genre ON track.genre_id = genre.genre_id
	WHERE genre.name LIKE 'Rock'
)
order by email;

--2. Let's invite the artists who have written the most rock music in our dataset. Write a 
--query that returns the Artist name and total track count of the top 10 rock bands

SELECT a.name, COUNT(t.*) as track_count FROM Artist as a 
JOIN Album as al ON a.artist_id=al.artist_id
JOIN track as t ON al.album_id=t.album_id
WHERE track_id IN(
	SELECT track_id FROM track
	JOIN genre ON track.genre_id = genre.genre_id
	WHERE genre.name LIKE 'Rock'
)
group by a.name 
order by track_count desc 
LIMIT 10;

--3. Return all the track names that have a song length longer than the average song length. 
--Return the Name and Milliseconds for each track. Order by the song length with the 
--longest songs listed first

SELECT name,milliseconds FROM track 
WHERE milliseconds>(SELECT AVG(milliseconds) as avg_track_length from track)
order by milliseconds desc;

--ADVANCE QUERIES

--1. Find how much amount spent by each customer on artists? Write a query to return
--customer name, artist name and total spent

WITH customer_invoices AS (
    SELECT c.customer_id, c.first_name, c.last_name, i.invoice_id
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
),
invoice_tracks AS (
    SELECT i.invoice_id, t.album_id, il.unit_price * il.quantity AS TotalPrice
    FROM invoice_line il
    JOIN track t ON il.track_id = t.track_id
    JOIN customer_invoices i ON il.invoice_id = i.invoice_id
),
album_artists AS (
    SELECT a.name AS ArtistName, al.album_id
    FROM album al
    JOIN artist a ON al.artist_id = a.artist_id
)
SELECT ci.first_name, ci.last_name, aa.ArtistName, SUM(it.TotalPrice) AS TotalSpent
FROM customer_invoices ci
JOIN invoice_tracks it ON ci.invoice_id = it.invoice_id
JOIN album_artists aa ON it.album_id = aa.album_id
GROUP BY ci.first_name,ci.last_name, aa.ArtistName ORDER BY TotalSpent desc;

--2. We want to find out the most popular music Genre for each country. We determine the 
--most popular genre as the genre with the highest amount of purchases. Write a query 
--that returns each country along with the top Genre. For countries where the maximum 
--number of purchases is shared return all Genres

WITH genre_sales AS (
    SELECT i.billing_country, g.Name AS Genre, SUM(il.quantity) AS Quantity
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON t.genre_id = g.genre_id
    GROUP BY i.billing_country, g.Name
),
max_genre_sales AS (
    SELECT billing_country, MAX(Quantity) AS MaxQuantity
    FROM genre_sales
    GROUP BY billing_country
)
SELECT gs.billing_country, gs.Genre, gs.Quantity
FROM genre_sales gs
JOIN max_genre_sales mgs ON gs.billing_country = mgs.billing_country AND gs.quantity = mgs.MaxQuantity
ORDER BY gs.billing_country;

--3. Write a query that determines the customer that has spent the most on music for each 
--country. Write a query that returns the country along with the top customer and how
--much they spent. For countries where the top amount spent is shared, provide all 
--customers who spent this amount

WITH customer_spending AS (
    SELECT c.customer_id, c.first_name, c.last_name, c.country, SUM(i.total) AS TotalSpent
    FROM customer c
    JOIN Invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id
),
max_spending AS (
    SELECT country, MAX(TotalSpent) AS MaxSpent
    FROM customer_spending
    GROUP BY country
)
SELECT cs.first_name, cs.last_name, cs.country, cs.TotalSpent
FROM customer_spending cs
JOIN max_spending ms ON cs.country = ms.country AND cs.TotalSpent = ms.MaxSpent;


