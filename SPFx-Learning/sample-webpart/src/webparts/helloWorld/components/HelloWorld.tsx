import * as React from 'react';
import { useState, useEffect, useCallback } from 'react';
import styles from './HelloWorld.module.scss';
import type { IHelloWorldProps } from './IHelloWorldProps';

interface IListItem {
  Id: number;
  Title: string;
  Modified?: string;
}

/**
 * Modern React Functional Component using Hooks
 * This demonstrates best practices for SPFx development in 2025/2026
 */
const HelloWorld: React.FC<IHelloWorldProps> = (props) => {
  // State management with useState hook
  const [items, setItems] = useState<IListItem[]>([]);
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  /**
   * Fetch items from SharePoint list using PnPjs
   * This is memoized with useCallback to prevent unnecessary re-renders
   */
  const fetchItems = useCallback(async () => {
    if (!props.listName) {
      setError('Please configure a list name in the web part properties');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      // Using PnPjs to fetch list items
      const listItems = await props.sp.web.lists
        .getByTitle(props.listName)
        .items
        .select('Id', 'Title', 'Modified')
        .top(10)();

      setItems(listItems);
    } catch (err) {
      console.error('Error fetching items:', err);
      setError(`Failed to load items from list "${props.listName}". ${(err as Error).message}`);
    } finally {
      setLoading(false);
    }
  }, [props.listName, props.sp]);

  /**
   * useEffect runs when component mounts and when dependencies change
   * Empty dependency array [] means it runs only once on mount
   * [fetchItems] means it runs when fetchItems function changes
   */
  useEffect(() => {
    if (props.listName) {
      fetchItems();
    }
  }, [fetchItems, props.listName]);

  /**
   * Render loading state
   */
  if (loading) {
    return (
      <section className={styles.helloWorld}>
        <div className={styles.welcome}>
          <div>Loading items...</div>
        </div>
      </section>
    );
  }

  /**
   * Render error state
   */
  if (error) {
    return (
      <section className={styles.helloWorld}>
        <div className={styles.welcome}>
          <div className={styles.error}>{error}</div>
          <button onClick={fetchItems}>Retry</button>
        </div>
      </section>
    );
  }

  /**
   * Main render
   */
  return (
    <section className={`${styles.helloWorld} ${props.hasTeamsContext ? styles.teams : ''}`}>
      <div className={styles.welcome}>
        <img
          alt=""
          src={require('../assets/welcome-light.png')}
          className={styles.welcomeImage}
        />
        <h2>Well done, {props.userDisplayName}!</h2>
        <div>{props.environmentMessage}</div>
        <div>Web part property value: <strong>{props.description}</strong></div>
      </div>

      <div>
        <h3>SharePoint List Items from: {props.listName || 'Not configured'}</h3>

        {items.length === 0 ? (
          <div>No items found or list not configured.</div>
        ) : (
          <div>
            <p>Found {items.length} item(s):</p>
            <ul className={styles.itemList}>
              {items.map((item) => (
                <li key={item.Id} className={styles.item}>
                  <strong>{item.Title}</strong>
                  {item.Modified && (
                    <span className={styles.modified}>
                      {' '}(Modified: {new Date(item.Modified).toLocaleDateString()})
                    </span>
                  )}
                </li>
              ))}
            </ul>
            <button onClick={fetchItems} className={styles.button}>
              Refresh Items
            </button>
          </div>
        )}
      </div>

      <div>
        <h3>Learn More About SPFx</h3>
        <ul className={styles.links}>
          <li>
            <a href="https://aka.ms/spfx" target="_blank" rel="noreferrer">
              SharePoint Framework Documentation
            </a>
          </li>
          <li>
            <a href="https://pnp.github.io/sp-dev-fx-webparts/" target="_blank" rel="noreferrer">
              PnP SPFx Samples
            </a>
          </li>
          <li>
            <a href="https://pnp.github.io/pnpjs/" target="_blank" rel="noreferrer">
              PnPjs Documentation
            </a>
          </li>
        </ul>
      </div>
    </section>
  );
};

export default HelloWorld;
